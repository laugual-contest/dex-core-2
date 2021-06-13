pragma ton-solidity >= 0.44.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

//================================================================================
//
import "../interfaces/IOwnable.sol";
import "../interfaces/IDexFactory.sol";
import "SymbolPair.sol";

//================================================================================
//
contract DexFactory is IDexFactory, IOwnable
{
    // Errors
    uint constant ERROR_SYMBOL_ALREADY_EXISTS      = 201;
    uint constant ERROR_SYMBOL_DOES_NOT_EXIST      = 202;
    uint constant ERROR_SYMBOLS_CANT_BE_THE_SAME   = 203;
    uint constant ERROR_SYMBOL_NOT_IN_VERIFICATION = 204;

    TvmCell public _symbolPairCode; // SymbolPair contract code;
    TvmCell public _LPWalletCode;   // SymbolPair Liquidity token wallet contract code;
    TvmCell public _RTWCode;        // TRC-5 RTW code;
    TvmCell public _TTWCode;        // TRC-5 TTW code;

    //========================================
    // Mappings
    mapping(address => Symbol) _listSymbols;
    mapping(address => Symbol) _listSymbolsAwaitingVerification;

    //========================================
    // Events

    //========================================
    // Inline functions
    function _sortAddresses(address addr1, address addr2) internal inline pure returns (address, address)
    {
        return (addr1 < addr2 ? (addr1, addr2) : (addr2, addr1));
    }

    //========================================
    // TODO: if code is not set don't allow to manage Factory
    function setSymbolPairCode(TvmCell code) external onlyOwner reserve returnChange {    _symbolPairCode = code;    }
    function setLPWalletCode  (TvmCell code) external onlyOwner reserve returnChange {    _LPWalletCode   = code;    }
    function setRTWCode       (TvmCell code) external onlyOwner reserve returnChange {    _RTWCode        = code;    }
    function setTTWCode       (TvmCell code) external onlyOwner reserve returnChange {    _TTWCode        = code;    }

    //========================================
    //
    function callbackVerifyTokenInfo(TokenInfo tokenInfo, bytes icon) public reserve
    {
        require(_listSymbolsAwaitingVerification[msg.sender].addressRTW == msg.sender, ERROR_SYMBOL_NOT_IN_VERIFICATION);

        _listSymbols[msg.sender].addressRTW = msg.sender;
        _listSymbols[msg.sender].addressTTW = addressZero;
        _listSymbols[msg.sender].name       = tokenInfo.name;
        _listSymbols[msg.sender].symbol     = tokenInfo.symbol;
        _listSymbols[msg.sender].decimals   = tokenInfo.decimals;
        _listSymbols[msg.sender].balance    = 0;
        _listSymbols[msg.sender].icon       = icon;
        
        delete _listSymbolsAwaitingVerification[msg.sender];
    }

    //========================================
    // 
    constructor() public
    {
        tvm.accept();
    }

    //========================================
    //
    function calculatePairFutureAddress(address symbol1RTW, address symbol2RTW) private inline view returns (address, TvmCell)
    {
        (address symbol1, address symbol2) = _sortAddresses(symbol1RTW, symbol2RTW);
        TokenInfo rootInfoLP;

        string name            = _listSymbols[symbol1].name;    name.append("-");    name.append(_listSymbols[symbol2].symbol);
        string symbol          = _listSymbols[symbol1].symbol;  symbol.append(_listSymbols[symbol2].symbol);
        rootInfoLP.name        = name;
        rootInfoLP.symbol      = symbol;
        rootInfoLP.decimals    = 9;
        rootInfoLP.totalSupply = 0;

        TvmCell stateInit = tvm.buildStateInit({
            contr: SymbolPair,
            varInit: {
                _walletCode:    _LPWalletCode,
                _rootInfo:      rootInfoLP,
                _factoryAddress: address(this),
                _symbol1RTW:    symbol1RTW,
                _symbol2RTW:    symbol2RTW
            },
            code: _symbolPairCode
        });

        return (address(tvm.hash(stateInit)), stateInit);
    }

    //========================================
    //
    function calculateRTWFutureAddress(TokenInfo info) private inline view returns (address, TvmCell)
    {
        TvmCell stateInit = tvm.buildStateInit({
            contr: LiquidFTRoot,
            varInit: {
                _walletCode: _TTWCode,
                _rootInfo:   info
            },
            code: _RTWCode
        });

        return (address(tvm.hash(stateInit)), stateInit);
    }

    //========================================
    //
    function createSymbol(bytes name, bytes symbol, uint8 decimals, bytes icon) external override reserve
    {
        TokenInfo info;
        info.name     = name;
        info.symbol   = symbol;
        info.decimals = decimals;

        (, TvmCell stateInit) = calculateRTWFutureAddress(info);
        new LiquidFTRoot{stateInit: stateInit, value: 0, flag: 128}(icon);
    }

    //========================================
    //
    function addSymbol(address symbolRTW) public override reserve
    {
        require(!_listSymbols.exists(symbolRTW), ERROR_SYMBOL_ALREADY_EXISTS);

        _listSymbolsAwaitingVerification[symbolRTW].addressRTW = symbolRTW;
        _listSymbolsAwaitingVerification[symbolRTW].addressTTW = addressZero;
        _listSymbolsAwaitingVerification[symbolRTW].balance    = 0;

        ILiquidFTRoot(symbolRTW).callRootInfo{value: 0, flag: 128, callback: callbackVerifyTokenInfo}();
    }

    //========================================
    //
    function addPair(address symbol1RTW, address symbol2RTW) external override reserve
    {
        require(symbol1RTW != symbol2RTW,        ERROR_SYMBOLS_CANT_BE_THE_SAME);
        require(_listSymbols.exists(symbol1RTW), ERROR_SYMBOL_DOES_NOT_EXIST   );
        require(_listSymbols.exists(symbol2RTW), ERROR_SYMBOL_DOES_NOT_EXIST   );

        (address symbol1, address symbol2) = _sortAddresses(symbol1RTW, symbol2RTW);
        
        (, TvmCell stateInit) = calculatePairFutureAddress(symbol1RTW, symbol2RTW);
        new SymbolPair{stateInit: stateInit, value: 0, flag: 128}("", _listSymbols[symbol1], _listSymbols[symbol2], msg.sender);
    }

    //========================================
    //
    function setProviderFee(address symbol1RTW, address symbol2RTW, uint16 fee) external override onlyOwner reserve
    {
        (address desierdAddress, ) = calculatePairFutureAddress(symbol1RTW, symbol2RTW);
        ISymbolPair(desierdAddress).setProviderFee(fee);
    }

    function getSymbolInfo(address symbolRTW) external view override returns (Symbol)
    {
        return _listSymbols[symbolRTW];
    }

    //========================================
    //
    function getPairAddress(address symbol1RTW, address symbol2RTW) external view override returns (address)
    {
        (address desiredAddress, ) = calculatePairFutureAddress(symbol1RTW, symbol2RTW);
        return desiredAddress;
    }
}

//================================================================================
//