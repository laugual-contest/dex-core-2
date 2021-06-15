pragma ton-solidity >= 0.44.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

//================================================================================
//
import "../interfaces/ILiquidFTRoot.sol";
import "../interfaces/ILiquidFTWallet.sol";
import "../interfaces/IOwnable.sol";
import "../contracts/LiquidFTWallet.sol";
import "../interfaces/ISymbolPair.sol";
import "../interfaces/IDexFactory.sol";

//================================================================================
//
contract SymbolPair is IOwnable, ILiquidFTRoot, ISymbolPair, iFTNotify
{
    //========================================
    // Error codes
    uint constant ERROR_WALLET_ADDRESS_INVALID = 301;
    uint constant ERROR_SENDER_IS_NOT_FACTORY  = 400;
    uint constant ERROR_SYMBOL_ADDRESS_INVALID = 401;
    uint constant ERROR_RTW_ADDRESS_INVALID    = 402;
    uint constant ERROR_NO_MINTING_IN_POOL     = 403;
    uint constant ERROR_DEPOSIT_TOO_SMALL      = 404;

    //========================================
    // Variables
    TvmCell static _walletCode;  //
    bytes   static _name;        //
    bytes   static _symbol;      //
    uint8   static _decimals;    //
    uint128        _totalSupply; //
    bytes          _icon;        // utf8-string with encoded PNG image. The string format is "data:image/png;base64,<image>", where image - image bytes encoded in base64.
                                 // _icon = "data:image/png;base64,iVBORw0KG...5CYII=";

    address public static _factoryAddress; //
    address public static _symbol1RTW;     //
    address public static _symbol2RTW;     //
    Symbol                _symbol1;
    Symbol                _symbol2;

    // TODO: move to a separate contract, mappings here are for simplicity in testing,
    //       but when it's the real deal each user's liquidity temporary storage should have its own contract;
    mapping(address => uint128) _limboSymbol1; // Liquidity that was transferred to the Pair but not yet applied;
    mapping(address => uint128) _limboSymbol2; // Liquidity that was transferred to the Pair but not yet applied;

    address public  _creatorAddress;      // User address that initiated pair creation
    uint16  public  _currentFee     = 30; // Current fee for Liquidity Providers to earn; Default 0.3%;  
    uint8   private _localDecimals  = 18; // 
    uint128 private _minimumDeposit = 100000;

    //========================================
    // Modifiers
    modifier onlyFactory {    require(msg.sender == _factoryAddress && _factoryAddress != addressZero, ERROR_SENDER_IS_NOT_FACTORY);    _;    }
    function walletsExist() internal inline view returns (bool) {    return (_symbol1.addressTTW != addressZero && _symbol2.addressTTW != addressZero);    }
    
    //========================================
    // Inline functions

    //========================================
    // Getters
    function  getWalletCode()                        external view             override         returns (TvmCell)         {                                                        return                      (_walletCode);       }
    function callWalletCode()                        external view responsible override reserve returns (TvmCell)         {                                                        return {value: 0, flag: 128}(_walletCode);       }
    function  getWalletAddress(address ownerAddress) external view             override         returns (address)         {    (address addr, ) = _getWalletInit(ownerAddress);    return                      (addr);              }
    function callWalletAddress(address ownerAddress) external view responsible override reserve returns (address)         {    (address addr, ) = _getWalletInit(ownerAddress);    return {value: 0, flag: 128}(addr);              }

    function  getRootInfo() external view override returns (bytes name, bytes symbol, uint8 decimals, uint128 totalSupply, bytes icon)
    {
        return (_name, _symbol, _decimals, _totalSupply, _icon);  
    }
    function callRootInfo() external view responsible override reserve returns (bytes name, bytes symbol, uint8 decimals, uint128 totalSupply, bytes icon)
    {
        return {value: 0, flag: 128}(_name, _symbol, _decimals, _totalSupply, _icon);
    }

    //========================================
    //
    constructor(bytes icon, Symbol symbol1, Symbol symbol2, address creatorAddress) public onlyFactory reserve
    {
        require(_symbol1RTW != addressZero && _symbol1RTW.isStdAddrWithoutAnyCast(), ERROR_SYMBOL_ADDRESS_INVALID);
        require(_symbol2RTW != addressZero && _symbol2RTW.isStdAddrWithoutAnyCast(), ERROR_SYMBOL_ADDRESS_INVALID);

        tvm.accept();
        _icon           = icon;
        _creatorAddress = creatorAddress;
        _symbol1        = symbol1;
        _symbol2        = symbol2;

        // Symbol Wallets
        _createWallets();
    }

    //========================================
    //
    function _createWallets() internal view
    {
        if(_symbol1.addressTTW == addressZero) {    ILiquidFTRoot(_symbol1RTW).callCreateWallet{value: msg.value / 2, flag: 0,   callback: _walletCreationCallback}(address(this), address(this), 0);    }
        if(_symbol2.addressTTW == addressZero) {    ILiquidFTRoot(_symbol2RTW).callCreateWallet{value: 0,             flag: 128, callback: _walletCreationCallback}(address(this), address(this), 0);    }
    }

    function createWallets() public view reserve 
    {
        _createWallets();
    }

    //========================================
    //
    function _walletCreationCallback(address walletAddress) public reserve
    {
        require(msg.sender == _symbol1RTW || msg.sender == _symbol2RTW, ERROR_WALLET_ADDRESS_INVALID);

        if(msg.sender == _symbol1RTW) {    _symbol1.addressTTW = walletAddress;    }
        if(msg.sender == _symbol2RTW) {    _symbol2.addressTTW = walletAddress;    }

        _creatorAddress.transfer(0, true, 128);
    }

    //========================================
    //
    function _getWalletInit(address ownerAddress) private inline view returns (address, TvmCell)
    {
        TvmCell stateInit = tvm.buildStateInit({
            contr: LiquidFTWallet,
            varInit: {
                _rootAddress:  address(this),
                _ownerAddress: ownerAddress
            },
            code: _walletCode
        });

        return (address(tvm.hash(stateInit)), stateInit);
    }

    //========================================
    //
    function _createWallet(address ownerAddress, address notifyOnReceiveAddress, uint128 tokensAmount, uint128 value, uint16 flag) internal returns (address)
    {
        if(tokensAmount > 0)
        {
            revert(ERROR_NO_MINTING_IN_POOL); // no minting when creating a wallet for liquidity tokens
        }
        
        (address walletAddress, TvmCell stateInit) = _getWalletInit(ownerAddress);
        // Event
        emit walletCreated(ownerAddress, walletAddress);

         new LiquidFTWallet{value: value, flag: flag, stateInit: stateInit, wid: address(this).wid}(msg.sender, notifyOnReceiveAddress, tokensAmount);

        return walletAddress;
    }

    //========================================
    //
    function createWallet(address ownerAddress, address notifyOnReceiveAddress, uint128 tokensAmount) external override reserve
    {
        _createWallet(ownerAddress, notifyOnReceiveAddress, tokensAmount, 0, 128);
    }

    function callCreateWallet(address ownerAddress, address notifyOnReceiveAddress, uint128 tokensAmount) external responsible override reserve returns (address)
    {
        address walletAddress = _createWallet(ownerAddress, notifyOnReceiveAddress, tokensAmount, msg.value / 2, 0);
        return{value: 0, flag: 128}(walletAddress);
    }

    //========================================
    //
    function burn(uint128 amount, address senderOwnerAddress, address initiatorAddress) external override reserve
    {
        (address walletAddress, ) = _getWalletInit(senderOwnerAddress);
        require(walletAddress == msg.sender, ERROR_WALLET_ADDRESS_INVALID);

        // Withdraw liquidity here
        TvmCell emptyBody;
        uint256 ratio = (_totalSupply * 10**uint256(_localDecimals)) / uint256(amount);
        uint128 amountSymbol1 = uint128((uint256(_symbol1.balance) * 10**uint256(_localDecimals)) / ratio);
        uint128 amountSymbol2 = uint128((uint256(_symbol2.balance) * 10**uint256(_localDecimals)) / ratio);

        ILiquidFTWallet(_symbol1.addressTTW).transfer{value: msg.value / 3, flag: 0}(amountSymbol1, senderOwnerAddress, initiatorAddress, addressZero, emptyBody);
        ILiquidFTWallet(_symbol2.addressTTW).transfer{value: msg.value / 3, flag: 0}(amountSymbol2, senderOwnerAddress, initiatorAddress, addressZero, emptyBody);

        // Adjust values
        _symbol1.balance -= amountSymbol1;
        _symbol2.balance -= amountSymbol2;
        _totalSupply     -= amount;       

        // Event
        emit tokensBurned(amount, senderOwnerAddress);

        // Return the change
        initiatorAddress.transfer(0, true, 128);
    }

    //========================================
    //
    function _mint(uint128 amount, address targetOwnerAddress, address notifyAddress, TvmCell body) private reserve
    {
        (address walletAddress, ) = _getWalletInit(targetOwnerAddress);

        // Event
        emit tokensMinted(amount, targetOwnerAddress);

        // Mint adds balance to root total supply
        _totalSupply += amount;
        ILiquidFTWallet(walletAddress).receiveTransfer{value: 0, flag: 128}(amount, addressZero, msg.sender, notifyAddress, body);
        
    }
    
    function mint(uint128 amount, address targetOwnerAddress, address notifyAddress, TvmCell body) public override onlyOwner reserve
    {
        _mint(amount, targetOwnerAddress, notifyAddress, body);
    }

    //========================================
    //
    onBounce(TvmSlice slice) external 
    {
		uint32 functionId = slice.decode(uint32);
		if (functionId == tvm.functionId(LiquidFTWallet.receiveTransfer)) 
        {
			uint128 amount = slice.decode(uint128);
            _totalSupply -= amount;

            // We know for sure that initiator in "mint" process is RTW owner;
            _ownerAddress.transfer(0, true, 128);
		}
	}

    //========================================
    // 
    function getPairLiquidity() external view override returns (Symbol symbol1, Symbol symbol2, uint256 liquidity, uint8 decimals) 
    {
        uint256 amount = _symbol1.balance  * _symbol2.balance;
        uint8   dcmls  = _symbol1.decimals + _symbol2.decimals;

        return (_symbol1, _symbol2, amount, dcmls);
    }

    //========================================
    // 
    function _getPairRatio(uint128 amount1, uint8 decimals1, uint128 amount2, uint8 decimals2) internal view returns (uint128, uint8)
    {
        // Empty
        if(amount1 == 0 || amount2 == 0)
        {
            return (0, 0);
        }

        uint256 ratio    = amount1;
        uint8   decimals = _localDecimals + decimals2 - decimals1;

        ratio = ratio * uint256(10**uint256(_localDecimals));
        ratio = ratio / uint256(amount2);

        return (uint128(ratio), decimals);
    }

    function getPairRatio(bool firstFirst) public view override returns (uint128, uint8)
    {
        Symbol symbol1 = firstFirst ? _symbol1 : _symbol2;
        Symbol symbol2 = firstFirst ? _symbol2 : _symbol1;

        return _getPairRatio(symbol1.balance, symbol1.decimals, symbol2.balance, symbol2.decimals);
    }

    //========================================
    //
    function setProviderFee(uint16 fee) external override onlyFactory reserve returnChange
    {
        _currentFee = fee;
    }

    function receiveNotification(uint128 amount, address senderOwnerAddress, address initiatorAddress, TvmCell body) external override reserve
    {
        require(msg.sender.isStdAddrWithoutAnyCast() && (msg.sender == _symbol1.addressTTW || msg.sender == _symbol2.addressTTW), ERROR_SYMBOL_ADDRESS_INVALID);

        TvmCell emptyBody;
        TvmSlice slice = body.toSlice();
        if(slice.empty() || !walletsExist())
        {
            // No body, return tokens back, we don't know what sender wanted
            ILiquidFTWallet(msg.sender).transfer{value: 0, flag: 128}(amount, senderOwnerAddress, initiatorAddress, addressZero, emptyBody);
        }
        else
        {
            uint8 operation = slice.decode(uint8);
            if(operation == uint8(OPERATION.SWAP))
            {
                (uint128 price, uint16 slippage) = slice.decode(uint128, uint16);
                
                address addressRTW = (msg.sender == _symbol1.addressTTW ? _symbol1.addressRTW : _symbol2.addressRTW);
                swap(addressRTW, amount, senderOwnerAddress, initiatorAddress, price, slippage);
            }
            else if(operation == uint8(OPERATION.DEPOSIT_LIQUIDITY))
            {
                // just deposit, update mappings
                     if(msg.sender == _symbol1.addressTTW) {    _limboSymbol1[senderOwnerAddress] += amount;    }
                else if(msg.sender == _symbol2.addressTTW) {    _limboSymbol2[senderOwnerAddress] += amount;    }
            }
        }
    }

    //========================================
    //
    function getPriceInternal(uint128 inputAmount, uint128 inputReserve, uint128 outputReserve) private view returns (uint128) 
    {
        uint256 inputAmountWithFee = uint256(inputAmount)        * (10000 - _currentFee);
        uint256 numerator          = uint256(inputAmountWithFee) * uint256(outputReserve);
        uint256 denominator        = uint256(inputReserve)       * 10000 + uint256(inputAmountWithFee);
        return uint128(numerator / denominator);
    }

    //========================================
    //
    function getPrice(address symbolSellRTW, uint128 amountToGive) public view override returns (uint128 price, uint8 decimals)
    {
        require(symbolSellRTW  == _symbol1.addressRTW || symbolSellRTW  == _symbol2.addressRTW, ERROR_RTW_ADDRESS_INVALID);

        Symbol symbolGet  = (symbolSellRTW == _symbol1.addressRTW ? _symbol2 : _symbol1); // 
        Symbol symbolGive = (symbolSellRTW == _symbol1.addressRTW ? _symbol1 : _symbol2); // 

        uint128 tokenReserve = symbolGet.balance;
        uint128 tokensToBuy = getPriceInternal(amountToGive, tokenReserve, symbolGive.balance);

        return (tokensToBuy, symbolGet.decimals);
    }

    //========================================
    //
    function swap(address symbolSellRTW, uint128 amount, address senderOwnerAddress, address initiatorAddress, uint128 price, uint16 slippage) internal
    {
        TvmCell emptyBody;
        Symbol symbolBuy  = (symbolSellRTW == _symbol1.addressRTW ? _symbol2 : _symbol1); // 
        Symbol symbolSell = (symbolSellRTW == _symbol1.addressRTW ? _symbol1 : _symbol2); // 

        (uint128 currentPrice, ) = getPrice(symbolSellRTW, amount);

        uint128 difference = 0;
        if(price > currentPrice) {    difference = 10000 - (currentPrice * 10000 / price);    }
        else                     {    difference = 10000 - (price * 10000 / currentPrice);    }

        if(symbolBuy.balance > 0 && currentPrice < symbolBuy.balance && difference <= slippage)
        {
            // Send tokens
            if(symbolSellRTW == _symbol1RTW) {    _symbol1.balance += amount;    _symbol2.balance -= currentPrice;    }
            else                             {    _symbol2.balance += amount;    _symbol1.balance -= currentPrice;    }

            emit swapSucceeded(symbolBuy.addressRTW, currentPrice, amount, initiatorAddress);

            ILiquidFTWallet(symbolBuy.addressTTW).transfer{value: 0, flag: 128}(currentPrice, senderOwnerAddress, initiatorAddress, addressZero, emptyBody);
        }
        else 
        {
            // Swap failed, send unused tokens back
            ILiquidFTWallet(symbolSell.addressTTW).transfer{value: 0, flag: 128}(currentPrice, senderOwnerAddress, initiatorAddress, addressZero, emptyBody);
        }
    }

    //========================================
    //
    function depositLiquidity(uint128 amountSymbol1, uint128 amountSymbol2, uint16 slippage) external override reserve
    {
        require(amountSymbol1 >= _minimumDeposit && amountSymbol2 >= _minimumDeposit, ERROR_DEPOSIT_TOO_SMALL);
        
        // Omit decimals here because we know they are the same
        (uint128 currentRatio, ) =  getPairRatio(true);
        (uint128 desiredRatio, ) = _getPairRatio(amountSymbol1, _symbol1.decimals, amountSymbol2, _symbol2.decimals);

        uint128 difference = 0;
        if(currentRatio > 0)
        {
            // Adjust deposit values if there's some slippage
            if(currentRatio > desiredRatio) {    difference = 10000 - (desiredRatio * 10000 / currentRatio);    amountSymbol2 = uint128(uint256(amountSymbol2) * uint256(currentRatio) / 10000);    }
            else                            {    difference = 10000 - (currentRatio * 10000 / desiredRatio);    amountSymbol1 = uint128(uint256(amountSymbol1) * uint256(currentRatio) / 10000);    }
        }

        if(difference <= slippage)
        {
            // Calculate LP tokens
            uint256 newLiquidity = 0;
            if(_symbol1.balance == 0) // If it's the first deposit
            {
                if(_localDecimals >= _symbol1.decimals) {    newLiquidity = amountSymbol1 * 10**(uint256(_localDecimals - _symbol1.decimals));    }
                else                                    {    newLiquidity = amountSymbol1 / 10**(uint256(_symbol1.decimals - _localDecimals));    }
            }
            else
            {
                uint256 liquidityRatio = (uint256(_symbol1.balance) * 10**uint256(_localDecimals)) / amountSymbol1;
                        newLiquidity   = (uint256(_totalSupply)     * 10**uint256(_localDecimals)) / liquidityRatio;
            }

            // Update values
            _symbol1.balance += amountSymbol1;
            _symbol2.balance += amountSymbol2;

            _limboSymbol1[msg.sender] -= amountSymbol1;
            _limboSymbol2[msg.sender] -= amountSymbol2;

            emit liquidityDeposited(amountSymbol1, amountSymbol2, msg.sender);

            // Mint
            TvmCell emptyBody;
            _mint(uint128(newLiquidity), msg.sender, addressZero, emptyBody);
        }
        else 
        {
            // Abort, do nothing, return change
            msg.sender.transfer(0, true, 128);
        }
    }
    
    //========================================
    //
    function collectLiquidityLeftovers() external override
    {
        TvmCell emptyBody;
        if(_limboSymbol1[msg.sender] > 0)
        {
            ILiquidFTWallet(_symbol1.addressTTW).transfer{value: msg.value / 2, flag: 0}(_limboSymbol1[msg.sender], msg.sender, msg.sender, addressZero, emptyBody);
            delete _limboSymbol1[msg.sender];
        }
        if(_limboSymbol2[msg.sender] > 0)
        {
            ILiquidFTWallet(_symbol2.addressTTW).transfer{value: 0, flag: 128}(_limboSymbol2[msg.sender], msg.sender, msg.sender, addressZero, emptyBody);
            delete _limboSymbol2[msg.sender];
        }
    }
}

//================================================================================
//