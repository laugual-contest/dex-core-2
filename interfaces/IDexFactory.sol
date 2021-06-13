pragma ton-solidity >= 0.44.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

//================================================================================
//
import "../interfaces/ISymbolPair.sol";
import "../contracts/LiquidFTRoot.sol";

//================================================================================
//
interface IDexFactory
{
    //========================================
    // Management
    //
    /// @notice Creates new TRC-5 Token and adds it to DEX. Root owner is msg.sender;
    ///
    /// @param name     - new Token name;
    /// @param symbol   - new Token symbol;
    /// @param decimals - new Token decimals;
    /// @param icon     - utf8-string with encoded PNG image (RFC 2397). The string format is "data:image/png;base64,<image>", where image - image bytes encoded in base64;
    //
    function createSymbol(bytes name, bytes symbol, uint8 decimals, bytes icon) external;
    
    /// @notice Adds an existing TRC-5 Token to DEX.
    ///         User who is adding the Token will pay all the fees:
    ///          - RTW creation;
    ///         Unspent change will be returned;
    ///
    /// @param symbolRTW  - RTW address of the Symbol (wallet); 
    //
    function addSymbol(address symbolRTW) external;

    /// @notice Adds a new SymbolPair to DEX; Both Symbols must be added beforehead; Order of the Symbols doesn't matter;
    ///         User who is adding the Token will pay all the fees:
    ///          - SymbolPair creation;
    ///          - SymbolPair TTW creation;
    ///         Unspent change will be returned;
    ///
    /// @param symbol1RTW - RTW address of the Symbol;
    /// @param symbol2RTW - RTW address of the Symbol;
    //
    function addPair(address symbol1RTW, address symbol2RTW) external;
    
    /// @notice Sets custom fee for a specific SymbolPair; Order of the Symbols doesn't matter;
    ///
    /// @param symbol1RTW - RTW address of the Symbol;
    /// @param symbol2RTW - RTW address of the Symbol;
    /// @param fee        - Fee value; default 3% = 30;
    //
    function setProviderFee(address symbol1RTW, address symbol2RTW, uint16 fee) external;

    /// @notice Gets Symbol information from Factory; If symbol does not exist returns an exception;
    ///
    /// @param symbolRTW - RTW address of the Symbol (wallet);
    //
    function getSymbolInfo(address symbolRTW) external view returns (Symbol);

    /// @notice Returns address of a specific SymbolPair contract, (0, 0) on fail; Order of the Symbols doesn't matter;
    ///
    /// @param symbol1RTW - RTW address of the Symbol (wallet);
    /// @param symbol2RTW - RTW address of the Symbol (wallet);
    //
    function getPairAddress(address symbol1RTW, address symbol2RTW) external view returns (address);
}

//================================================================================
//