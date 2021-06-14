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
    function callbackVerifyTokenInfo(bytes name, bytes symbol, uint8 decimals, uint128 totalSupply, bytes icon) public reserve
    {
        require(_listSymbolsAwaitingVerification[msg.sender].addressRTW == msg.sender, ERROR_SYMBOL_NOT_IN_VERIFICATION);

        // Silence the warning
        totalSupply = 0;

        Symbol _symbol;
        _symbol.addressRTW = msg.sender;
        _symbol.addressTTW = addressZero;
        _symbol.name       = name;
        _symbol.symbol     = symbol;
        _symbol.decimals   = decimals;
        _symbol.balance    = 0;
        _symbol.icon       = icon;
        
        _listSymbols[msg.sender] = _symbol;

        delete _listSymbolsAwaitingVerification[msg.sender];
    }

    //========================================
    // 
    constructor(address ownerAddress) public
    {
        tvm.accept();
        _ownerAddress = ownerAddress;
    }

    //========================================
    //
    function calculatePairFutureAddress(address symbol1RTW, address symbol2RTW) private inline view returns (address, TvmCell)
    {
        (address symbol1, address symbol2) = _sortAddresses(symbol1RTW, symbol2RTW);

        string name   = _listSymbols[symbol1].name;    name.append("-");    name.append(_listSymbols[symbol2].symbol);
        string symbol = _listSymbols[symbol1].symbol;  symbol.append(_listSymbols[symbol2].symbol);


        TvmCell stateInit = tvm.buildStateInit({
            contr: SymbolPair,
            varInit: {
                _walletCode:    _LPWalletCode,
                _name:           name,
                _symbol:         symbol,
                _decimals:       9,
                _factoryAddress: address(this),
                _symbol1RTW:     symbol1RTW,
                _symbol2RTW:     symbol2RTW
            },
            code: _symbolPairCode
        });

        return (address(tvm.hash(stateInit)), stateInit);
    }

    //========================================
    //
    function calculateRTWFutureAddress(bytes name, bytes symbol, uint8 decimals, uint256 initialPubkey) private inline view returns (address, TvmCell)
    {
        TvmCell stateInit = tvm.buildStateInit({
            contr: LiquidFTRoot,
            varInit: {
                _walletCode: _TTWCode,
                _name:        name,
                _symbol:      symbol,
                _decimals:    decimals
            },
            pubkey: initialPubkey,
            code:  _RTWCode
        });

        return (address(tvm.hash(stateInit)), stateInit);
    }

    //========================================
    //
    function createSymbol(bytes name, bytes symbol, uint8 decimals, bytes icon, uint256 initialPubkey) external override reserve
    {
        TokenInfo info;
        info.name     = name;
        info.symbol   = symbol;
        info.decimals = decimals;

        (, TvmCell stateInit) = calculateRTWFutureAddress(name, symbol, decimals, initialPubkey);
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
        ISymbolPair(desierdAddress).setProviderFee{value:0, flag: 128}(fee);
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

    //========================================
    //
    function getCellContents(uint8 operation, uint128 price, uint16 slippage) external pure returns (TvmCell)
    {
        TvmBuilder builder;
        builder.store(operation, price, slippage);
        return builder.toCell();
    }
}

//================================================================================
//