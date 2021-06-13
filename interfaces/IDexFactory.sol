pragma ton-solidity >= 0.38.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

//================================================================================
//
import "../interfaces/ISymbolPair.sol";

//================================================================================
//
interface IDexFactory
{
    //========================================
    // Callbacks
    //
    function callback_VerifyTokenDetails(bytes name, bytes symbol, uint8 decimals) external;
    //function callback_AddTTW(address addressTTW, uint128 grams, uint256 walletPublicKey, address ownerAddress) external;
    
    //========================================
    // Management
    //
    /// @notice Adds a new Symbol to DEX; Can be called by anyone (not only Owner or Governance);
    ///         When called, new Symbol will be added and then verified automatically;
    ///         NOTE: currently DexFactory uses its own funds (tvm.accept()) to manage this function, thus
    ///               one can perform an attack and spend all the funds of the contract; it is made for
    ///               simplicity of DEX Stage 1 Implementation;
    ///         TODO: add TTL to temporary entries to stop DexFactory contract from growing; 
    ///
    /// @param symbolRTW  - RTW address of the Symbol (wallet); 
    //
    function addSymbol(address symbolRTW) external;

    /// @notice Adds a new SymbolPair to DEX; Both Symbols must be added beforehead; Order of the Symbols doesn't matter;
    ///
    /// @param symbol1RTW - RTW address of the Symbol (wallet);
    /// @param symbol2RTW - RTW address of the Symbol (wallet);
    //
    function addPair(address symbol1RTW, address symbol2RTW) external;
    
    /// @notice Sets custom fee for a specific SymbolPair; Order of the Symbols doesn't matter;
    ///
    /// @param symbol1RTW - RTW address of the Symbol (wallet);
    /// @param symbol2RTW - RTW address of the Symbol (wallet);
    /// @param fee        - Fee value; default 3% = 30;
    //
    function setProviderFee(address symbol1RTW, address symbol2RTW, uint16 fee) external;

    /// @notice Checks if the Symbol exists in DexFactory;
    ///
    /// @param symbolRTW - RTW address of the Symbol (wallet);
    //
    function symbolExists(address symbolRTW) external view returns (bool);

    /// @notice Returns address of a specific SymbolPair contract, (0, 0) on fail; Order of the Symbols doesn't matter;
    ///
    /// @param symbol1RTW - RTW address of the Symbol (wallet);
    /// @param symbol2RTW - RTW address of the Symbol (wallet);
    //
    function getPairAddress(address symbol1RTW, address symbol2RTW) external view returns (address);

    /// @notice Returns addresses of all SymbolPairs contracts;
    //
    //function getAllPairs() external view returns (address[]);
}

//================================================================================
//