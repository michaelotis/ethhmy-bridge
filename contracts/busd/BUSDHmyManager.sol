pragma solidity 0.5.17;

import "./IBUSD.sol";
import "../lib/TokenManager.sol";

contract BUSDHmyManager {
    IBUSD public hBUSD;
    address public eBUSD;
    address public tokenManager;

    mapping(bytes32 => bool) public usedEvents_;

    event Burned(
        address indexed token,
        address indexed sender,
        uint256 amount,
        address recipient
    );

    event Minted(uint256 amount, address recipient);

    mapping(address => uint256) public wards;

    function rely(address guy) external auth {
        wards[guy] = 1;
    }

    function deny(address guy) external auth {
        require(guy != owner, "HmyManager/cannot deny the owner");
        wards[guy] = 0;
    }

    modifier auth {
        require(wards[msg.sender] == 1, "HmyManager/not-authorized");
        _;
    }

    address public owner;

    /**
     * @dev constructor
     * @param _hBUSD harmony busd token contract address
     * @param _eBUSD ethereum busd token contract address
     * @param _tokenManager token manager contract address
     */
    constructor(
        address _hBUSD,
        address _eBUSD,
        address _tokenManager
    ) public {
        owner = msg.sender;
        wards[msg.sender] = 1;
        hBUSD = IBUSD(_hBUSD);
        eBUSD = _eBUSD;
        tokenManager = _tokenManager;
        TokenManager(tokenManager).registerToken(eBUSD, address(hBUSD));
    }

    /**
    * @dev deregister token mapping in the token manager
    */
    function deregister() public auth {
        TokenManager(tokenManager).removeToken(eBUSD, 0);
    }

    /**
     * @dev burns tokens on harmony to be unlocked on ethereum
     * @param amount amount of tokens to burn
     * @param recipient recipient of the unlock tokens on ethereum
     */
    function burnToken(uint256 amount, address recipient) public {
        require(
            hBUSD.transferFrom(msg.sender, address(this), amount),
            "HmyManager/could not transfer tokens from user"
        );
        require(hBUSD.decreaseSupply(amount), "HmyManager/burn failed");
        emit Burned(address(hBUSD), msg.sender, amount, recipient);
    }

    /**
     * @dev mints tokens corresponding to the tokens locked in the ethereum chain
     * @param amount amount of tokens for minting
     * @param recipient recipient of the minted tokens (harmony address)
     * @param receiptId transaction hash of the lock event on ethereum chain
     */
    function mintToken(
        uint256 amount,
        address recipient,
        bytes32 receiptId
    ) public auth {
        require(
            !usedEvents_[receiptId],
            "HmyManager/The lock event cannot be reused"
        );
        usedEvents_[receiptId] = true;
        require(hBUSD.increaseSupply(amount), "HmyManager/mint failed");
        require(
            hBUSD.transfer(recipient, amount),
            "HmyManager/transfer after mint failed"
        );
        emit Minted(amount, recipient);
    }
}
