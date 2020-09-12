pragma solidity 0.5.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./BridgedToken.sol";

contract TokenManager {
    // ethtoken to onetoken mapping
    mapping(address => address) public mappedTokens;

    event TokenMapAck(address indexed tokenReq, address indexed tokenAck);

    mapping(address => uint256) public wards;

    function rely(address guy) external auth {
        wards[guy] = 1;
    }

    function deny(address guy) external auth {
        require(guy != owner, "TokenManager/cannot deny the owner");
        wards[guy] = 0;
    }

    // both owner and admin must approve
    modifier auth {
        require(wards[msg.sender] == 1, "TokenManager/not-authorized");
        _;
    }

    address public owner;

    /**
     * @dev constructor
     */
    constructor() public {
        owner = msg.sender;
        wards[owner] = 1;
    }

    /**
     * @dev map ethereum token to harmony token and emit mintAddress
     * @param ethTokenAddr address of the ethereum token
     * @return mintAddress of the mapped token
     */
    function addToken(address ethTokenAddr) public auth returns (address) {
        require(
            ethTokenAddr != address(0),
            "TokenManager/ethToken is a zero address"
        );
        require(
            mappedTokens[ethTokenAddr] == address(0),
            "TokenManager/ethToken already mapped"
        );

        ERC20Detailed tokenDetail = ERC20Detailed(ethTokenAddr);
        BridgedToken bridgedToken = new BridgedToken(
            tokenDetail.name(),
            tokenDetail.symbol(),
            tokenDetail.decimals()
        );
        address bridgedTokenAddr = address(bridgedToken);

        // store the mapping and created address
        mappedTokens[ethTokenAddr] = bridgedTokenAddr;

        // assign minter role to the caller
        bridgedToken.addMinter(msg.sender);

        emit TokenMapAck(ethTokenAddr, bridgedTokenAddr);
        return bridgedTokenAddr;
    }

    /**
     * @dev register an ethereum token to harmony token mapping
     * @param ethTokenAddr address of the ethereum token
     * @return oneToken of the mapped harmony token
     */
    function registerToken(address ethTokenAddr, address oneTokenAddr)
        public
        auth
        returns (bool)
    {
        require(
            ethTokenAddr != address(0),
            "TokenManager/ethTokenAddr is a zero address"
        );
        require(
            mappedTokens[ethTokenAddr] == address(0),
            "TokenManager/ethTokenAddr already mapped"
        );

        // store the mapping and created address
        mappedTokens[ethTokenAddr] = oneTokenAddr;
    }

    /**
     * @dev remove an existing token mapping
     * @param ethTokenAddr address of the ethereum token
     * @param supply only allow removing mapping when supply, e.g., zero or 10**27
     */
    function removeToken(address ethTokenAddr, uint256 supply) public auth {
        IERC20 erc20Token = IERC20(ethTokenAddr);
        require(
            erc20Token.totalSupply() == supply,
            "TokenManager/remove has non-zero supply"
        );
        delete mappedTokens[ethTokenAddr];
    }
}