pragma ton-solidity >= 0.44.0;
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
    bytes   icon;       //
}

enum OPERATION
{
    SWAP,
    DEPOSIT_LIQUIDITY,
    NUM
}

//================================================================================
//
interface ISymbolPair
{
    //========================================
    // Events
    event swapSucceeded     (address buyRTW, uint128 amountBought, uint128 amountSold, address initiatorAddress);
    event liquidityDeposited(uint128 amountSymbol1, uint128 amountSymbol2, address initiatorAddress);
    
    //========================================
    //
    /// @notice Gets Symbol1 info, Symbol2 info, total pool liquidity and liquidity decimals;
    //
    function getPairLiquidity() external view returns (Symbol, Symbol, uint256, uint8);

    //========================================
    //
    /// @notice Gets pair ratio;
    ///
    /// @param firstFirst - get ratio symbol1/symbol2 or symbol2/symbol1;
    //
    function getPairRatio(bool firstFirst) external view returns (uint128, uint8);

    //========================================
    //
    /// @notice Gets price for given amount of tokens;
    ///
    /// @param symbolSellRTW - Symbol RTW to sell;
    /// @param amountToGive - Amount of tokens to sell;
    //
    function getPrice(address symbolSellRTW, uint128 amountToGive) external view returns (uint128, uint8);

    //========================================
    //
    /// @notice Sets the fee that Liquidity Providers ger from each trade; 1% = 100; 100% = 10000;
    ///
    /// @param fee - Fee value; default 3% = 30;
    //
    function setProviderFee(uint16 fee) external;
    
    //========================================
    //
    /// @notice Deposits liquidity from Limbo to the pool; User gets LP tokens in return;
    ///
    /// @param amountSymbol1 - Amount of Synbol 1 to deposit;
    /// @param amountSymbol2 - Amount of Symbol 2 to deposit;
    /// @param slippage      - Slippage threshold in percents (1% = 100) after which operation is aborted;
    //
    function depositLiquidity(uint128 amountSymbol1, uint128 amountSymbol2, uint16 slippage) external;

    //========================================
    //
    /// @notice Collects tokens that were not deposited to the pool back to user wallets;
    //
    function collectLiquidityLeftovers() external;
}

//================================================================================
//
