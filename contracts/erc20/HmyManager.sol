pragma solidity 0.5.17;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../lib/TokenManager.sol";

interface MintableToken {
    function mint(address beneficiary, uint256 amount) external returns (bool);
}

interface BurnableToken {
    function burnFrom(address account, uint256 amount) external;
}

contract HmyManager {
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
    address public tokenManager;

    mapping(address => address) public mappings;

    /**
     * @dev constructor
     * @param _tokenManager token manager address on harmony chain
     */
    constructor(address _tokenManager) public {
        owner = msg.sender;
        wards[owner] = 1;
        tokenManager = _tokenManager;
    }

    /**
     * @dev change token manager
     * @param newTokenManager new token manager address on harmony chain
     */
    function changeTokenManager(address newTokenManager) public auth {
        tokenManager = newTokenManager;
    }

    /**
     * @dev map an ethereum token to harmony
     * @param ethTokenAddr ethereum token address to map
     */
    function addToken(address ethTokenAddr) public returns (address) {
        address oneTokenAddr = TokenManager(tokenManager).addToken(
            ethTokenAddr
        );
        mappings[ethTokenAddr] = oneTokenAddr;
        return oneTokenAddr;
    }

    /**
     * @dev deregister token mapping in the token manager
     */
    function removeToken(address ethTokenAddr) public auth {
        TokenManager(tokenManager).removeToken(ethTokenAddr, 0);
    }

    /**
     * @dev burns tokens on harmony to be unlocked on ethereum
     * @param amount amount of tokens to burn
     * @param recipient recipient of the unlock tokens on ethereum
     */
    function burnToken(
        address oneToken,
        uint256 amount,
        address recipient
    ) public {
        BurnableToken(oneToken).burnFrom(msg.sender, amount);
        emit Burned(oneToken, msg.sender, amount, recipient);
    }

    /**
     * @dev mints tokens corresponding to the tokens locked in the ethereum chain
     * @param oneToken is the token address for minting
     * @param amount amount of tokens for minting
     * @param recipient recipient of the minted tokens (harmony address)
     * @param receiptId transaction hash of the lock event on ethereum chain
     */
    function mintToken(
        address oneToken,
        uint256 amount,
        address recipient,
        bytes32 receiptId
    ) public auth {
        require(
            !usedEvents_[receiptId],
            "HmyManager/The lock event cannot be reused"
        );
        usedEvents_[receiptId] = true;
        MintableToken(oneToken).mint(recipient, amount);
        emit Minted(amount, recipient);
    }
}
