pragma solidity 0.5.17;

import "./ILINK.sol";
import "../lib/TokenManager.sol";

contract LINKHmyManager {
    ILINK public hLINK;
    address public eLINK;
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
     * @param _hLINK harmony token contract address
     * @param _eLINK ethereum token contract address
     * @param _tokenManager token manager contract address
     */
    constructor(
        address _hLINK,
        address _eLINK,
        address _tokenManager
    ) public {
        owner = msg.sender;
        wards[msg.sender] = 1;
        hLINK = ILINK(_hLINK);
        eLINK = _eLINK;
        tokenManager = _tokenManager;
        TokenManager(tokenManager).registerToken(eLINK, address(hLINK));
    }

    /**
     * @dev deregister token mapping in the token manager
     */
    function deregister() public auth {
        TokenManager(tokenManager).removeToken(eLINK, 10**27);
    }

    /**
     * @dev burns tokens on harmony to be unlocked on ethereum
     * @param amount amount of tokens to burn
     * @param recipient recipient of the unlock tokens on ethereum
     */
    function burnToken(uint256 amount, address recipient) public {
        require(
            hLINK.transferFrom(msg.sender, address(this), amount),
            "HmyManager/burn failed"
        );
        emit Burned(address(hLINK), msg.sender, amount, recipient);
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
            "HmyManager/The unlock event cannot be reused"
        );
        usedEvents_[receiptId] = true;
        require(hLINK.transfer(recipient, amount), "HmyManager/mint failed");
        emit Minted(amount, recipient);
    }
}
