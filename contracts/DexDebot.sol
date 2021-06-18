pragma ton-solidity >=0.44.0;
pragma AbiHeader time;
pragma AbiHeader pubkey;
pragma AbiHeader expire;

//================================================================================
//
/// @title DexDebot
/// @author Augual.Team
/// @notice Debot for Augual.DEX (LiquiSOR) service

//================================================================================
//
import "../interfaces/IDexFactory.sol";
import "../interfaces/ISymbolPair.sol";
import "../interfaces/ILiquidFTRoot.sol";
import "../interfaces/ILiquidFTWallet.sol";
import "../interfaces/IDebot.sol";
import "../interfaces/IUpgradable.sol";
import "../interfaces/debot/address.sol";
import "../interfaces/debot/amount.sol";
import "../interfaces/debot/menu.sol";
import "../interfaces/debot/number.sol";
import "../interfaces/debot/sdk.sol";
import "../interfaces/debot/terminal.sol";

//================================================================================
//
interface IMsig 
{
    /// @dev Allows custodian if she is the only owner of multisig to transfer funds with minimal fees.
    /// @param dest Transfer target address.
    /// @param value Amount of funds to transfer.
    /// @param bounce Bounce flag. Set true if need to transfer funds to existing account;
    /// set false to create new account.
    /// @param flags `sendmsg` flags.
    /// @param payload Tree of cells used as body of outbound internal message.
    function sendTransaction(
        address dest,
        uint128 value,
        bool bounce,
        uint8 flags,
        TvmCell payload) external view;
}

//================================================================================
//
contract DexDebot is Debot, Upgradable
{
    //TvmCell _domainCode;
    //TvmCell _deployerCode;    
    
    address  _factoryAddress;
    address  _symbolPairAddress;
    int8     _symbolPairAccState;

    address  _msigAddress;
    Symbol[] _symbolsList;
    Symbol   _selectedSymbol1;
    Symbol   _selectedSymbol2;
    address  _lpWalletAddress;
    uint128  _depositAmount1;
    uint128  _depositAmount2;
    uint16   _depositSlippage;

    // Provide liquidity
    Symbol   _provideLiquiditySymbol;
    address  _provideLiquidityWalletAddress;

    // Trade
    Symbol   _tradeSellSymbol;
    Symbol   _tradeBuySymbol;
    address  _tradeSellWalletAddress;
    address  _tradeBuyWalletAddress;
    uint128  _sellAmount;
    uint128  _buyAmount;
    
    /*string   ctx_name;
    address  ctx_domain;
    DnsWhois ctx_whois;
    int8     ctx_accState;
    uint8    ctx_segments;
    address  ctx_parent;*/

    optional(uint256) _emptyPk;

    uint128 constant ATTACH_VALUE = 0.5 ton;

	//========================================
    //
    constructor(address ownerAddress) public 
    {
        _ownerAddress = ownerAddress;
        tvm.accept();
    }
    
    //========================================
    //
    function setFactoryAddress(address factoryAddress) public {
        require(msg.pubkey() == tvm.pubkey() || senderIsOwner(), 100);
        tvm.accept();
        _factoryAddress = factoryAddress;
    }    

	//========================================
    //
	function getRequiredInterfaces() public pure returns (uint256[] interfaces) 
    {
        return [Terminal.ID, AddressInput.ID, NumberInput.ID, AmountInput.ID, Menu.ID];
	}

    //========================================
    //
    function getDebotInfo() public functionID(0xDEB) view returns(string name,     string version, string publisher, string key,  string author,
                                                                  address support, string hello,   string language,  string dabi, bytes icon)
    {
        name      = "LiquiSOR DEX DeBot (Augual.TEAM)";
        version   = "0.2.0";
        publisher = "Augual.TEAM";
        key       = "LiquiSOR DEX from Augual.TEAM";
        author    = "Augual.TEAM";
        support   = addressZero;
        hello     = "Welcome to LiquiSOR DEX DeBot!";
        language  = "en";
        dabi      = m_debotAbi.hasValue() ? m_debotAbi.get() : "";
        icon      = m_icon.hasValue()     ? m_icon.get()     : "";
    }

    //========================================
    /// @notice Define DeBot version and title here.
    function getVersion() public override returns (string name, uint24 semver) 
    {
        (name, semver) = ("DexDebot", _version(0, 2, 0));
    }

    function _version(uint24 major, uint24 minor, uint24 fix) private pure inline returns (uint24) 
    {
        return (major << 16) | (minor << 8) | (fix);
    }    

    //========================================
    // Implementation of Upgradable
    function onCodeUpgrade() internal override 
    {
        tvm.resetStorage();
    }

    //========================================
    //
    function onError(uint32 sdkError, uint32 exitCode) public 
    {
        //     if (exitCode == ERROR_MESSAGE_SENDER_IS_NOT_MY_OWNER)      {    Terminal.print(0, "Failed! You're not the owner of this domain.");               }
        //else if (exitCode == ERROR_REQUIRE_INTERNAL_MESSAGE_WITH_VALUE) {    Terminal.print(0, "Failed! No value attached.");                                 }
        //else if (exitCode == ERROR_DOMAIN_IS_EXPIRED)                   {    Terminal.print(0, "Failed! Domain is expired.");                                 }
        //else if (exitCode == ERROR_DOMAIN_IS_NOT_EXPIRED)               {    Terminal.print(0, "Failed! Domain is not expired.");                             }
        //else if (exitCode == ERROR_CAN_NOT_PROLONGATE_YET)              {    Terminal.print(0, "Failed! Can't prolong yet.");                                 }
        //else if (exitCode == ERROR_NOT_ENOUGH_MONEY)                    {    Terminal.print(0, "Failed! Not enough value attached to cover domain price.");   }
        //else
        {
            Terminal.print(0, format("Failed! SDK Error: {}. Exit Code: {}", sdkError, exitCode));
        }     

        mainMenu(0); 
    }

    //========================================
    // Inline functions
    function _sortSymbols(Symbol sym1, Symbol sym2) internal inline pure returns (Symbol, Symbol)
    {
        return (sym1.addressRTW < sym2.addressRTW ? (sym1, sym2) : (sym2, sym1));
    }

    //========================================
    /// @notice Entry point function for DeBot.    
    function start() public override 
    {
        mainMenu(0);
    }

    //========================================
    //
    function _eraseCtx() internal 
    {
        _msigAddress    = addressZero;
        delete _symbolsList;
        /*ctx_domain     = addressZero;  
        ctx_name       = "";
        ctx_accState   = 0;
        ctx_segments   = 0;
        ctx_parent     = addressZero;
        delete ctx_whois; // reset custom struct without specifying all the members*/
    }    

    //========================================
    //
    function getSymbolRepresentation(Symbol symbol) public pure returns (string)
    {
        string text;
        text.append("(");
        text.append(symbol.symbol);
        text.append(") ");
        text.append(symbol.name);
        return text;
    }

    //========================================
    //
    function mainMenu(uint32 index) public 
    {
        _eraseCtx();
        index = 0; // shut a warning

        if(_factoryAddress == addressZero)
        {
            //Terminal.print(0, "DeBot is being upgraded.\nPlease come back in a minute.\nSorry for inconvenience.");
            return;
        }

        AddressInput.get(tvm.functionId(onMsigEnter), "Let's start with entering your Multisig Wallet address: ");
    }

    //========================================
    //
    function onMsigEnter(address value) public
    {  
        _msigAddress = value;
        _refreshSymbols_1(0);
    }

    //========================================
    //========================================
    //========================================
    //========================================
    //========================================
    //
    function _refreshSymbols_1(uint32 index) public view
    {
        index = 0; // shut a warning
        IDexFactory(_factoryAddress).getSymbolsList{
                        abiVer: 2,
                        extMsg: true,
                        sign: false,
                        time: uint64(now),
                        expire: 0,
                        pubkey: _emptyPk,
                        callbackId: tvm.functionId(_refreshSymbols_2),
                        onErrorId:  tvm.functionId(onError)
                        }();
    }

    function _refreshSymbols_2(Symbol[] symbols) public
    {
        _symbolsList = symbols;
        _mainLoop(0);
    }
    
    //========================================
    //========================================
    //========================================
    //========================================
    //========================================
    //
    function _mainLoop(uint32 index) public 
    {
        index = 0; // shut a warning

        MenuItem[] mi;
        mi.push(MenuItem("List Symbols",      "", tvm.functionId(_listSymbols_1)     ));
        mi.push(MenuItem("Refresh Symbols",   "", tvm.functionId(_refreshSymbols_1)  ));
        mi.push(MenuItem("Add Symbol",        "", tvm.functionId(_addSymbol_1)       ));
        mi.push(MenuItem("Get Symbol Pair",   "", tvm.functionId(_getSymbolPair_1)   ));
        mi.push(MenuItem("<- Restart",        "", tvm.functionId(mainMenu)           ));
        Menu.select("Enter your choice: ", "", mi);
    }

    //========================================
    //========================================
    //========================================
    //========================================
    //========================================
    //
    function _listSymbols_1(uint32 index) public
    {
        index = 0; // shut a warning
        
        string text;
        for(Symbol symbol : _symbolsList)
        {
            if(text.byteLength() > 0){    text.append("\n");    }
            text.append(getSymbolRepresentation(symbol));
        }

        Terminal.print(0, text);

        _mainLoop(0);
    }

    //========================================
    //========================================
    //========================================
    //========================================
    //========================================
    //
    function _addSymbol_1(uint32 index) public
    {
        index = 0; // shut a warning
        AddressInput.get(tvm.functionId(_addSymbol_2), "Please enter TRC-6 RTW address: ");
    }

    function _addSymbol_2(address value) public
    {  
        TvmCell body = tvm.encodeBody(IDexFactory.addSymbol, value);
        _sendTransact(_msigAddress, _factoryAddress, body, ATTACH_VALUE);
        _addSymbol_3(0);
    }

    function _addSymbol_3(uint32 index) public
    {  
        index = 0; // shut a warning

        Terminal.print(0, "Adding symbol, please wait for ~10 seconds and refresh Symbols list");
        _mainLoop(0);
    }

    //========================================
    //========================================
    //========================================
    //========================================
    //========================================
    //
    function _getSymbolPair_1(uint32 index) public
    {
        index = 0; // shut a warning

        delete _selectedSymbol1;
        delete _selectedSymbol2;
        
        Terminal.print(0, "Please choose the first Symbol:");
        MenuItem[] mi;
        for(Symbol symbol : _symbolsList)
        {
            mi.push(MenuItem(getSymbolRepresentation(symbol), "", tvm.functionId(_getSymbolPair_2)));
        }
        Menu.select("Enter your choice: ", "", mi);
    }

    function _getSymbolPair_2(uint32 index) public
    {
        _selectedSymbol1 = _symbolsList[index];
        
        Terminal.print(0, "Please choose the second Symbol:");
        MenuItem[] mi;
        for(Symbol symbol : _symbolsList)
        {
            //if(symbol.addressRTW == _selectedSymbol1.addressRTW) {    continue;    }

            mi.push(MenuItem(getSymbolRepresentation(symbol), "", tvm.functionId(_getSymbolPair_3)));
        }
        Menu.select("Enter your choice: ", "", mi);
    }

    function _getSymbolPair_3(uint32 index) public
    {
        _selectedSymbol2 = _symbolsList[index];
        if(_selectedSymbol2.addressRTW == _selectedSymbol1.addressRTW)
        {
            Terminal.print(0, "You can't choose same Symbol twice!");
            _getSymbolPair_1(0);
            return;
        }

        //(_selectedSymbol1, _selectedSymbol2) = _sortSymbols(_selectedSymbol1, _selectedSymbol2);

        IDexFactory(_factoryAddress).getPairAddress{
                        abiVer: 2,
                        extMsg: true,
                        sign: false,
                        time: uint64(now),
                        expire: 0,
                        pubkey: _emptyPk,
                        callbackId: tvm.functionId(_getSymbolPair_4),
                        onErrorId:  tvm.functionId(onError)
                        }(_selectedSymbol1.addressRTW, _selectedSymbol2.addressRTW);
    }

    function _getSymbolPair_4(address value) public
    {
        _symbolPairAddress = value;
        Sdk.getAccountType(tvm.functionId(_getSymbolPair_5), _symbolPairAddress);
    }

    function _getSymbolPair_5(int8 acc_type) public 
    {
        _symbolPairAccState = acc_type;
        _getSymbolPair_6(0);
    }

    function _getSymbolPair_6(uint32 index) public 
    {
        index = 0; // shut a warning

        if (_symbolPairAccState == -1 || _symbolPairAccState == 0) 
        {
            Terminal.print(0, format("Symbol Pair does not exist!"));

            MenuItem[] mi;
            mi.push(MenuItem("Deploy Pair", "", tvm.functionId(_symbolPairDeploy_1)));
            mi.push(MenuItem("<- Go back",  "", tvm.functionId(_mainLoop)          ));
            mi.push(MenuItem("<- Restart",  "", tvm.functionId(mainMenu)           ));
            Menu.select("Enter your choice: ", "", mi);
        }
        else if (_symbolPairAccState == 1)
        {
            _symbolPairMenu_1(0);
        } 
        else if (_symbolPairAccState == 2)
        {
            Terminal.print(0, format("Symbol Pair is FROZEN."));
            _mainLoop(0); 
        }
    }

    //========================================
    //========================================
    //========================================
    //========================================
    //========================================
    //
    function _symbolPairDeploy_1(uint32 index) public
    {
        index = 0; // shut a warning

        TvmCell body = tvm.encodeBody(IDexFactory.addPair, _selectedSymbol1.addressRTW, _selectedSymbol2.addressRTW);
        _sendTransact(_msigAddress, _factoryAddress, body, ATTACH_VALUE * 2);
        _symbolPairDeploy_2(1);
    }

    function _symbolPairDeploy_2(uint32 index) public
    {
        index = 0; // shut a warning
        Sdk.getAccountType(tvm.functionId(_symbolPairDeploy_3), _symbolPairAddress);
    }

    function _symbolPairDeploy_3(int8 acc_type) public
    {
        // Loop like crazy until we get the Pair
        if(acc_type == 1) {    _symbolPairMenu_1(0);    }
        else              {    _symbolPairDeploy_2(0);  }
    }
        
    //========================================
    //========================================
    //========================================
    //========================================
    //========================================
    //
    function _symbolPairMenu_1(uint32 index) public view
    {
        index = 0; // shut a warning

        ISymbolPair(_symbolPairAddress).getPairLiquidity{
                        abiVer: 2,
                        extMsg: true,
                        sign: false,
                        time: uint64(now),
                        expire: 0,
                        pubkey: _emptyPk,
                        callbackId: tvm.functionId(_symbolPairMenu_2),
                        onErrorId:  tvm.functionId(onError)
                        }();
    }
    
    function _symbolPairMenu_2(Symbol symbol1, Symbol symbol2, uint256 liquidity, uint8 decimals) public
    {
        _selectedSymbol1 = symbol1;
        _selectedSymbol2 = symbol2;
        
        // TODO: show Pair info;
        string text1 = format("SYMBOL 1\nName: {}\nSymbol: {}\nDecimals: {}\nIn Pool: {}", symbol1.name, symbol1.symbol, symbol1.decimals, symbol1.balance);
        string text2 = format("SYMBOL 2\nName: {}\nSymbol: {}\nDecimals: {}\nIn Pool: {}", symbol2.name, symbol2.symbol, symbol2.decimals, symbol2.balance);
        string text3 = format("Liquidity: {}\nLiquidity decimals: {}", liquidity, decimals);

        Terminal.print(0, text1);
        Terminal.print(0, text2);
        Terminal.print(0, text3);

        MenuItem[] mi;
        mi.push(MenuItem("Trade",               "", tvm.functionId(_symbolPairTrade_1)                     ));
        mi.push(MenuItem("Provide liquidity",   "", tvm.functionId(_symbolPairProvideLiquidity_1)          ));
        mi.push(MenuItem("Get liquidity limbo", "", tvm.functionId(_symbolPairGetLiquidityLimbo_1)         ));
        mi.push(MenuItem("Deposit liquidity",   "", tvm.functionId(_symbolPairDepositLiquidity_1)          ));
        mi.push(MenuItem("Withdraw liquidity",  "", tvm.functionId(_symbolPairWithdrawLiquidity_1)         ));
        mi.push(MenuItem("Withdraw leftovers",  "", tvm.functionId(_symbolPairWithdrawLiquidityLeftovers_1)));

        mi.push(MenuItem("<- Go back", "", tvm.functionId(_mainLoop)          ));
        mi.push(MenuItem("<- Restart", "", tvm.functionId(mainMenu)           ));
        Menu.select("Enter your choice: ", "", mi);
    }

    //========================================
    //========================================
    //========================================
    //========================================
    //========================================
    // 
    function _symbolPairGetLiquidityLimbo_1(uint32 index) public view
    {
        index = 0; // shut a warning

        ISymbolPair(_symbolPairAddress).getUserLimbo{
                        abiVer: 2,
                        extMsg: true,
                        sign: false,
                        time: uint64(now),
                        expire: 0,
                        pubkey: _emptyPk,
                        callbackId: tvm.functionId(_symbolPairGetLiquidityLimbo_2),
                        onErrorId:  tvm.functionId(onError)
                        }(_msigAddress);
    }

    function _symbolPairGetLiquidityLimbo_2(uint128 amount1, uint128 amount2) public
    {
        Terminal.print(0, format("Symbol1: {}\nSymbol2: {}", amount1, amount2));

        _symbolPairMenu_1(0);
    }
    
    //========================================
    //========================================
    //========================================
    //========================================
    //========================================
    // TODO: including wallet deployment
    function _symbolPairTrade_1(uint32 index) public
    {
        index = 0; // shut a warning

        delete _tradeSellSymbol;
        delete _tradeBuySymbol;

        Terminal.print(0, format("Select a symbol to sell:"));
        MenuItem[] mi;
        mi.push(MenuItem(getSymbolRepresentation(_selectedSymbol1), "", tvm.functionId(_symbolPairTrade_2) ));
        mi.push(MenuItem(getSymbolRepresentation(_selectedSymbol2), "", tvm.functionId(_symbolPairTrade_2) ));

        mi.push(MenuItem("<- Go back", "", tvm.functionId(_mainLoop) ));
        mi.push(MenuItem("<- Restart", "", tvm.functionId(mainMenu)  ));
        Menu.select("Enter your choice: ", "", mi);
    }

    function _symbolPairTrade_2(uint32 index) public
    {
        _tradeSellSymbol = (index == 0 ? _selectedSymbol1 : _selectedSymbol2);
        _tradeBuySymbol  = (index == 0 ? _selectedSymbol2 : _selectedSymbol1);

        ILiquidFTRoot(_tradeSellSymbol.addressRTW).getWalletAddress{
                        abiVer: 2,
                        extMsg: true,
                        sign: false,
                        time: uint64(now),
                        expire: 0,
                        pubkey: _emptyPk,
                        callbackId: tvm.functionId(_symbolPairTrade_3),
                        onErrorId:  tvm.functionId(onError)
                        }(_msigAddress);
    }
    
    function _symbolPairTrade_3(address value) public
    {
        _tradeSellWalletAddress = value;
        Sdk.getAccountType(tvm.functionId(_symbolPairTrade_4), _tradeSellWalletAddress);
    }

    function _symbolPairTrade_4(int8 acc_type) public
    {
        if (acc_type == -1 || acc_type == 0) 
        {
            Terminal.print(0, format("You don't have a Token wallet, you can't trade!"));
            _symbolPairMenu_1(0); 
        }
        else if (acc_type == 1)
        {
            _symbolPairTrade_5(0);
        } 
        else if (acc_type == 2)
        {
            Terminal.print(0, format("Your Token wallet Wallet is FROZEN."));
            _mainLoop(0); 
        }
    }

    function _symbolPairTrade_5(uint32 index) public view
    {
        index = 0; // shut a warning

        ILiquidFTRoot(_tradeBuySymbol.addressRTW).getWalletAddress{
                        abiVer: 2,
                        extMsg: true,
                        sign: false,
                        time: uint64(now),
                        expire: 0,
                        pubkey: _emptyPk,
                        callbackId: tvm.functionId(_symbolPairTrade_6),
                        onErrorId:  tvm.functionId(onError)
                        }(_msigAddress);
    }

    function _symbolPairTrade_6(address value) public
    {
        _tradeBuyWalletAddress = value;
        Sdk.getAccountType(tvm.functionId(_symbolPairTrade_7), _tradeBuyWalletAddress);
    }

    function _symbolPairTrade_7(int8 acc_type) public
    {
        if (acc_type == -1 || acc_type == 0) 
        {
            Terminal.print(0, format("Deploy receiver TTW first!"));
            TvmCell body = tvm.encodeBody(ILiquidFTRoot.createWallet, _msigAddress, addressZero, 0);
            _sendTransact(_msigAddress, _tradeBuySymbol.addressRTW, body, ATTACH_VALUE);
            _symbolPairTrade_8(0); 
        }
        else if (acc_type == 1)
        {
            _symbolPairTrade_8(0);
        } 
        else if (acc_type == 2)
        {
            Terminal.print(0, format("Your Token wallet Wallet is FROZEN."));
            _mainLoop(0); 
        }
    }

    function _symbolPairTrade_8(uint32 index) public
    {
        index = 0; // shut a warning
        AmountInput.get(tvm.functionId(_symbolPairTrade_9), format("Enter amount of {} to sell: ", _tradeSellSymbol.symbol), _tradeSellSymbol.decimals, 0, 999999999999999999999999999999);
    }

    function _symbolPairTrade_9(uint256 value) public
    {
        _sellAmount = uint128(value);

        ISymbolPair(_symbolPairAddress).getPrice{
                        abiVer: 2,
                        extMsg: true,
                        sign: false,
                        time: uint64(now),
                        expire: 0,
                        pubkey: _emptyPk,
                        callbackId: tvm.functionId(_symbolPairTrade_10),
                        onErrorId:  tvm.functionId(onError)
                        }(_tradeSellSymbol.addressRTW, _sellAmount);
    }

    function _symbolPairTrade_10(uint128 amount, uint8 decimals) public
    {
        _buyAmount = amount;
        decimals = 0;  // shut a warning
        Terminal.print(0, format("You are selling {} amount of {} and will get {} amount of {} in return. OK?", _sellAmount, _tradeSellSymbol.symbol, _buyAmount, _tradeBuySymbol.symbol));

        MenuItem[] mi;
        mi.push(MenuItem("YES", "",             tvm.functionId(_symbolPairTrade_11) ));
        mi.push(MenuItem("Nah, get me out", "", tvm.functionId(_symbolPairMenu_1)   ));
        Menu.select("Enter your choice: ", "", mi);
    }

    function _symbolPairTrade_11(uint32 index) public view
    {
        index = 0; // shut a warning
        TvmBuilder builder;
        builder.store(uint8(0), _buyAmount, uint16(500)); // TODO: slippage is forced to 5%, ash user to enter number instead
        TvmCell body = tvm.encodeBody(ILiquidFTWallet.transfer, uint128(_sellAmount), _symbolPairAddress, _msigAddress, addressZero, builder.toCell());
        _sendTransact(_msigAddress, _tradeSellWalletAddress, body, ATTACH_VALUE);
        _symbolPairMenu_1(0);
    }
    
    //========================================
    //========================================
    //========================================
    //========================================
    //========================================
    //
    function _symbolPairProvideLiquidity_1(uint32 index) public
    {
        index = 0; // shut a warning
        delete _provideLiquiditySymbol;

        MenuItem[] mi;
        mi.push(MenuItem(getSymbolRepresentation(_selectedSymbol1), "", tvm.functionId(_symbolPairProvideLiquidity_2) ));
        mi.push(MenuItem(getSymbolRepresentation(_selectedSymbol2), "", tvm.functionId(_symbolPairProvideLiquidity_2) ));

        mi.push(MenuItem("<- Go back",  "", tvm.functionId(_mainLoop) ));
        mi.push(MenuItem("<- Restart",  "", tvm.functionId(mainMenu)  ));
        Menu.select("Enter your choice: ", "", mi);
    }

    function _symbolPairProvideLiquidity_2(uint32 index) public
    {
        _provideLiquiditySymbol = (index == 0 ? _selectedSymbol1 : _selectedSymbol2);

        ILiquidFTRoot(_provideLiquiditySymbol.addressRTW).getWalletAddress{
                        abiVer: 2,
                        extMsg: true,
                        sign: false,
                        time: uint64(now),
                        expire: 0,
                        pubkey: _emptyPk,
                        callbackId: tvm.functionId(_symbolPairProvideLiquidity_3),
                        onErrorId:  tvm.functionId(onError)
                        }(_msigAddress);
    }

    function _symbolPairProvideLiquidity_3(address value) public
    {
        _provideLiquidityWalletAddress = value;
        Sdk.getAccountType(tvm.functionId(_symbolPairProvideLiquidity_4), _provideLiquidityWalletAddress);
    }

    function _symbolPairProvideLiquidity_4(int8 acc_type) public
    {
        if (acc_type == -1 || acc_type == 0) 
        {
            Terminal.print(0, format("You don't have a Token wallet!"));
            _symbolPairMenu_1(0); 
        }
        else if (acc_type == 1)
        {
            _symbolPairProvideLiquidity_5(0);
        } 
        else if (acc_type == 2)
        {
            Terminal.print(0, format("Your Token wallet Wallet is FROZEN."));
            _mainLoop(0); 
        }
    }

    function _symbolPairProvideLiquidity_5(uint32 index) public
    {
        index = 0; // shut a warning
        
        AmountInput.get(tvm.functionId(_symbolPairProvideLiquidity_6), format("Enter amount of {} to deposit: ", _provideLiquiditySymbol.symbol), _provideLiquiditySymbol.decimals, 0, 999999999999999999999999999999);
    }

    function _symbolPairProvideLiquidity_6(uint256 value) public view
    {
        TvmBuilder builder;
        builder.store(uint8(1), uint128(0), uint16(0));
        TvmCell body = tvm.encodeBody(ILiquidFTWallet.transfer, uint128(value), _symbolPairAddress, _msigAddress, addressZero, builder.toCell());
        _sendTransact(_msigAddress, _provideLiquidityWalletAddress, body, ATTACH_VALUE);
        _symbolPairMenu_1(0);
    }
    
    //========================================
    //========================================
    //========================================
    //========================================
    //========================================
    // TODO: including LP wallet deployment
    function _symbolPairDepositLiquidity_1(uint32 index) public view
    {
        index = 0; // shut a warning

        ILiquidFTRoot(_symbolPairAddress).getWalletAddress{
                        abiVer: 2,
                        extMsg: true,
                        sign: false,
                        time: uint64(now),
                        expire: 0,
                        pubkey: _emptyPk,
                        callbackId: tvm.functionId(_symbolPairDepositLiquidity_2),
                        onErrorId:  tvm.functionId(onError)
                        }(_msigAddress);
    }
    
    function _symbolPairDepositLiquidity_2(address value) public
    {
        _lpWalletAddress = value;
        Sdk.getAccountType(tvm.functionId(_symbolPairDepositLiquidity_3), _lpWalletAddress);
    }

    function _symbolPairDepositLiquidity_3(int8 acc_type) public
    {
        if (acc_type == -1 || acc_type == 0) 
        {
            // TODO: notify that we are deploying LP wallet; +
            //       also, check that wallet was created;
            Terminal.print(0, "You don't have LP wallet, deploy?");

            TvmCell body = tvm.encodeBody(ILiquidFTRoot.createWallet, _msigAddress, addressZero, 0);
            _sendTransact(_msigAddress, _symbolPairAddress, body, ATTACH_VALUE);
            _symbolPairDepositLiquidity_4(0);
        }
        else if (acc_type == 1)
        {
            _symbolPairDepositLiquidity_4(0);
        } 
        else if (acc_type == 2)
        {
            Terminal.print(0, format("Your LP Wallet is FROZEN."));
            _mainLoop(0); 
        }
    }

    function _symbolPairDepositLiquidity_4(uint32 index) public
    {
        index = 0; // shut a warning
        AmountInput.get(tvm.functionId(_symbolPairDepositLiquidity_5), format("Enter amount of {} to deposit: ", _selectedSymbol1.symbol), _selectedSymbol1.decimals, 0, 999999999999999999999999999999);
    }

    function _symbolPairDepositLiquidity_5(uint256 value) public
    {
        _depositAmount1 = uint128(value);
        AmountInput.get(tvm.functionId(_symbolPairDepositLiquidity_6), format("Enter amount of {} to deposit: ", _selectedSymbol2.symbol), _selectedSymbol2.decimals, 0, 999999999999999999999999999999);
    }

    function _symbolPairDepositLiquidity_6(uint256 value) public
    {
        _depositAmount2 = uint128(value);
        AmountInput.get(tvm.functionId(_symbolPairDepositLiquidity_7), "Enter Slippage in %: ", 2, 0, 10000);
    }

    function _symbolPairDepositLiquidity_7(uint256 value) public
    {
        _depositSlippage = uint16(value);
        
        // TODO: text?
        TvmCell body = tvm.encodeBody(ISymbolPair.depositLiquidity, _depositAmount1, _depositAmount2, uint16(_depositSlippage));
        _sendTransact(_msigAddress, _symbolPairAddress, body, ATTACH_VALUE);

        _symbolPairMenu_1(0);
    }
    
    //========================================
    //========================================
    //========================================
    //========================================
    //========================================
    // TODO: we catually can be missing TTWs if we just bought liquidity tokens
    function _symbolPairWithdrawLiquidity_1(uint32 index) public view
    {
        index = 0; // shut a warning

        ILiquidFTRoot(_symbolPairAddress).getWalletAddress{
                        abiVer: 2,
                        extMsg: true,
                        sign: false,
                        time: uint64(now),
                        expire: 0,
                        pubkey: _emptyPk,
                        callbackId: tvm.functionId(_symbolPairWithdrawLiquidity_2),
                        onErrorId:  tvm.functionId(onError)
                        }(_msigAddress);
    }

    function _symbolPairWithdrawLiquidity_2(address value) public
    {
        _lpWalletAddress = value;
        Sdk.getAccountType(tvm.functionId(_symbolPairWithdrawLiquidity_3), _lpWalletAddress);
    }

    function _symbolPairWithdrawLiquidity_3(int8 acc_type) public
    {
        if (acc_type == -1 || acc_type == 0) 
        {
            // TODO: notify that we are deploying LP wallet; +
            //       also, check that wallet was created;
            Terminal.print(0, "Oops, looks like you don't have LP wallet, that means you don't have liquidity to withdraw (sorry bout that).");
            _symbolPairMenu_1(0);
        }
        else if (acc_type == 1)
        {
            _symbolPairWithdrawLiquidity_4(0);
        } 
        else if (acc_type == 2)
        {
            Terminal.print(0, format("Your LP Wallet is FROZEN (oopsie)."));
            _symbolPairMenu_1(0);
        }
    }

    function _symbolPairWithdrawLiquidity_4(uint32 index) public view
    {
        index = 0; // shut a warning

        ILiquidFTWallet(_lpWalletAddress).getBalance{
                        abiVer: 2,
                        extMsg: true,
                        sign: false,
                        time: uint64(now),
                        expire: 0,
                        pubkey: _emptyPk,
                        callbackId: tvm.functionId(_symbolPairWithdrawLiquidity_5),
                        onErrorId:  tvm.functionId(onError)
                        }();
    }

    function _symbolPairWithdrawLiquidity_5(uint128 balance) public
    {
        Terminal.print(0, format("You currently have {} Liquidity tokens.", balance));
        AmountInput.get(tvm.functionId(_symbolPairWithdrawLiquidity_6), "Enter amount to withdraw: ", 18, 0, 999999999999999999999999999999);
    }
    
    function _symbolPairWithdrawLiquidity_6(int256 value) public view
    {
        TvmCell body = tvm.encodeBody(ILiquidFTWallet.burn, uint128(value));
        _sendTransact(_msigAddress, _lpWalletAddress, body, ATTACH_VALUE);

        _symbolPairMenu_1(0); // TODO: other menu? maybe some message?
    }
    
    //========================================
    //========================================
    //========================================
    //========================================
    //========================================
    //
    function _symbolPairWithdrawLiquidityLeftovers_1(uint32 index) public view
    {
        index = 0; // shut a warning

        TvmCell body = tvm.encodeBody(ISymbolPair.collectLiquidityLeftovers);
        _sendTransact(_msigAddress, _symbolPairAddress, body, ATTACH_VALUE);

        _symbolPairMenu_1(0); // TODO: other menu? maybe some message?
    }







    //========================================
    //
    // 1. main menu: add symbol, get symbol pair to trade
    // 2.1. if adding symbol, enter rtw address;
    // 2.2. after entering send transaction and go to main menu
    // 3.1. if getting symbol, show list of symbols to choose 1st
    // 3.2. show list of symbols to choose 2nd
    // 3.3. check if pair exists, if it doesn't ask to deploy it
    // 3.4. if pair exists get pair information and show current info.
    // 4. get three wallets silently (we need to know if user has wallet A, wallet B and liquidity wallet)
    // 4. you need to choose, buy, sell, deposit, finalize or withdraw leftovers;
    // 4.1. if depositing, if walletA or walletB doesn't exist, say you can't deposit without wallets and go to menu 4;
    // 4.3. ask to send amount of symbol A
    // 4.4. ask to send amount of symbol B
    // 4.5. if finalizing, ask to create LP wallet if it doesn't exist;
    // 4.6. if finalizing, show current leftovers and pair ratio ask the amount symbol A to deposit;
    // 4.7. calculate symbol B based on amount, ask what slippage is good;
    // 4.8. send finalize;
    // 5. if buying, ask to create wallets that you don't have before that;
    // 5.1. after that ask for the amount to buy;
    // 5.2. ask for the slippage to buy;
    // 5.3. send transaction;
    // 6. if withdraw leftovers, we know that both wallets exist, just do that;

    //========================================
    //
    function _sendTransact(address msigAddr, address dest, TvmCell payload, uint128 grams) internal pure
    {
        IMsig(msigAddr).sendTransaction{
            abiVer: 2,
            extMsg: true,
            sign: true,
            callbackId: 0,
            onErrorId: tvm.functionId(onError),
            time: uint32(now),
            expire: 0,
            pubkey: 0x00
        }(dest,
          grams,
          false,
          1,
          payload);
    }
}

//================================================================================
//