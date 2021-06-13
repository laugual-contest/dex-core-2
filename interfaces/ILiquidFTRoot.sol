pragma ton-solidity >= 0.44.0;
pragma AbiHeader time;
pragma AbiHeader pubkey;
pragma AbiHeader expire;

//================================================================================
//
struct TokenInfo
{
    bytes   name;        // Token name;
    bytes   symbol;      // Token symbol;
    uint8   decimals;    // Token decimals;
    uint128 totalSupply; // Token total supply;
}

//================================================================================
//
interface iFTNotify
{
    function receiveNotification(uint128 amount, address senderOwnerAddress, address initiatorAddress, TvmCell body) external;
}

//================================================================================
//
interface ILiquidFTRoot
{
    //========================================
    // Events
    event tokensMinted (uint128 amount,       address targetOwnerAddress);
    event walletCreated(address ownerAddress, address walletAddress     );
    event tokensBurned (uint128 amount,       address senderOwnerAddress);

    //========================================
    // Getters
    function  getWalletCode()                        external view             returns (TvmCell);                             // Wallet code;
    function callWalletCode()                        external view responsible returns (TvmCell);                             // Wallet code, responsible;
    function  getRootInfo()                          external view             returns (bytes, bytes, uint8, uint128, bytes); // Token information + icon;
    function callRootInfo()                          external view responsible returns (bytes, bytes, uint8, uint128, bytes); // Token information + icon, responsible;
    function  getWalletAddress(address ownerAddress) external view             returns (address);                             // Arbitratry Wallet address;
    function callWalletAddress(address ownerAddress) external view responsible returns (address);                             // Arbitratry Wallet address, responsible;

    //========================================
    /// @notice Receives burn command from Wallet;
    ///
    /// @dev Burn is performed by Wallet, not by Root owner;
    ///
    /// @param amount             - Amount of tokens to burn;
    /// @param senderOwnerAddress - Sender Wallet owner address to calculate and verify Wallet address;
    /// @param initiatorAddress   - Transaction initiator (e.g. Multisig) to return the unspent change;
    //
    function burn(uint128 amount, address senderOwnerAddress, address initiatorAddress) external;

    //========================================
    /// @notice Mints tokens from Root to a target Wallet;
    ///
    /// @param amount             - Amount of tokens to mint;
    /// @param targetOwnerAddress - Receiver Wallet owner address to calculate Wallet address;
    /// @param notifyAddress      - "iFTNotify" contract address to receive a notification about minting (may be zero);
    /// @param body               - Custom body (business-logic specific, may be empty);
    //
    function mint(uint128 amount, address targetOwnerAddress, address notifyAddress, TvmCell body) external;

    //========================================
    /// @notice Creates a new Wallet with 0 Tokens; Anyone can call this (not only Root);
    ///
    /// @param ownerAddress           - Receiver Wallet owner address to calculate Wallet address;
    /// @param tokensAmount           - When called by Root Owner, you can mint Tokens when creating a wallet;
    /// @param notifyOnReceiveAddress - "iFTNotify" contract address to receive a notification when Wallet receives a transfer;
    //
    function createWallet(address ownerAddress, address notifyOnReceiveAddress, uint128 tokensAmount) external;

    //========================================
    /// @notice Creates a new Wallet with 0 Tokens; Anyone can call this (not only Root);
    ///         Returns wallet address;
    ///
    /// @param ownerAddress           - Receiver Wallet owner address to calculate Wallet address;
    /// @param tokensAmount           - When called by Root Owner, you can mint Tokens when creating a wallet;
    /// @param notifyOnReceiveAddress - "iFTNotify" contract address to receive a notification when Wallet receives a transfer;
    //
    function callCreateWallet(address ownerAddress, address notifyOnReceiveAddress, uint128 tokensAmount) external responsible returns (address);
}

//================================================================================
//
