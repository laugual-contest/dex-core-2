pragma ton-solidity >= 0.38.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

//================================================================================
//
import "../interfaces/ILiquidFTRoot.sol";

struct Symbol
{
    address addressRTW;  // Root Token Wallet for symbol;
    address addressTTW;  // TON  Token Wallet for symbol;
    bytes   name;       //
    bytes   symbol;     //
    uint8   decimals;   //
    uint128 balance;    //
}

enum OPERATION
{
    SWAP,
    DEPOSIT_LIQUIDITY
}

//================================================================================
//
interface ISymbolPair
{
    //========================================
    //
    /// @notice Sets the fee that Liquidity Providers ger from each trade; 1% = 100; 100% = 10000;
    ///
    /// @param fee - Fee value; default 3% = 30;
    //
    function setProviderFee(uint16 fee) external;

    //========================================
    // Liquidity
    //function getPairRatio(bool firstFirst)                                                             external view returns (uint256, uint8); // Returns current pool ratio and decimals, is needed to perform correct "depositLiquidity";
    //function depositLiquidity (uint128 amount1, uint128 amount2, address ttwToken1, address ttwToken2) external;                               // ORDER OF SYMBOLS MATTERS
    //function withdrawLiquidity(uint256 amountLiquidity)                                                external;                               //
    //function getPairLiquidity ()                                                                       external view returns (uint256, uint8); //
    //function getUserLiquidity (uint256 ownerPubKey)                                                    external view returns (uint256, uint8); //
    //function getUserTotalLiquidity()                                                                   external view returns (uint256, uint8); //

    // Trading
    //function getPrice  (address RTW_ofTokenToGet, address RTW_ofTokenToGive, uint128 amountToGive) external view returns (uint256, uint8);
    //function swapTokens(address tokenToGet, address tokenToGive, uint128 amountToGive, address ttwTokenToGet, address ttwTokenToGive) external;

    // Callbacks
    //function callbackDeployEmptyWallet        (address newWalletAddress,       uint128 grams, uint256 walletPublicKey, address ownerAddress) external;
    //function callbackSwapGetTTWAddress        (address targetAddress,                         uint256 walletPublicKey, address ownerAddress) external;
    //function callbackDepositGetTTWAddress     (address targetAddress,                         uint256 walletPublicKey, address ownerAddress) external;
    //function callbackSendTokensWithResolve    (uint errorCode, uint128 tokens, uint128 grams, uint256 pubKeyToResolve                      ) external;
    //function callbackSwapGetTransferResult    (uint errorCode, uint128 tokens,                                         address to          ) external;
    //function callbackDepositGetTransferResult2(uint errorCode, uint128 tokens,                                         address to          ) external;
    //function callbackDepositGetTransferResult (uint errorCode, uint128 tokens,                                         address to          ) external;
}

//================================================================================
//
