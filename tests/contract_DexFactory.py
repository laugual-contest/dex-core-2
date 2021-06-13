#!/usr/bin/env python3

# ==============================================================================
#
import freeton_utils
from   freeton_utils import *

class DexFactory(object):
    def __init__(self, tonClient: TonClient, signer: Signer):
        self.SIGNER      = generateSigner() if signer is None else signer
        self.TONCLIENT   = tonClient
        self.ABI         = "../bin/DexFactory.abi.json"
        self.TVC         = "../bin/DexFactory.tvc"
        self.CODE        = getCodeFromTvc(self.TVC)
        self.CONSTRUCTOR = {}
        self.INITDATA    = {}
        self.PUBKEY      = self.SIGNER.keys.public
        self.ADDRESS     = getAddress(abiPath=self.ABI, tvcPath=self.TVC, signer=signer, initialPubkey=self.PUBKEY, initialData=self.INITDATA)

    def deploy(self, ownerAddress: str):
        self.CONSTRUCTOR = {"ownerAddress":ownerAddress}
        result = deployContract(tonClient=self.TONCLIENT, abiPath=self.ABI, tvcPath=self.TVC, constructorInput=self.CONSTRUCTOR, initialData=self.INITDATA, signer=self.SIGNER, initialPubkey=self.PUBKEY)
        return result
        
    def _call(self, functionName, functionParams, signer):
        result = callFunction(tonClient=self.TONCLIENT, abiPath=self.ABI, contractAddress=self.ADDRESS, functionName=functionName, functionParams=functionParams, signer=signer)
        return result

    def _callFromMultisig(self, msig: SetcodeMultisig, functionName, functionParams, value, flags):
        messageBoc = prepareMessageBoc(abiPath=self.ABI, functionName=functionName, functionParams=functionParams)
        result     = msig.callTransfer(addressDest=self.ADDRESS, value=value, payload=messageBoc, flags=flags)
        return result

    def _run(self, functionName, functionParams):
        result = runFunction(tonClient=self.TONCLIENT, abiPath=self.ABI, contractAddress=self.ADDRESS, functionName=functionName, functionParams=functionParams)
        return result

    #========================================
    #
    def setSymbolPairCode(self, msig: SetcodeMultisig, value: int, code: str):
        result = self._callFromMultisig(msig=msig, functionName="setSymbolPairCode", functionParams={"code":code}, value=value, flags=1)
        return result

    def setLPWalletCode(self, msig: SetcodeMultisig, value: int, code: str):
        result = self._callFromMultisig(msig=msig, functionName="setLPWalletCode", functionParams={"code":code}, value=value, flags=1)
        return result

    def setRTWCode(self, msig: SetcodeMultisig, value: int, code: str):
        result = self._callFromMultisig(msig=msig, functionName="setRTWCode", functionParams={"code":code}, value=value, flags=1)
        return result

    def setTTWCode(self, msig: SetcodeMultisig, value: int, code: str):
        result = self._callFromMultisig(msig=msig, functionName="setTTWCode", functionParams={"code":code}, value=value, flags=1)
        return result

    #========================================
    #
    def createSymbol(self, msig: SetcodeMultisig, value: int, name: str, symbol: str, decimals: int, icon: str):
        result = self._callFromMultisig(msig=msig, functionName="createSymbol", functionParams={"amount":amount, "targetOwnerAddress":targetOwnerAddress, "notifyAddress":notifyAddress, "body":body}, value=value, flags=1)
        return result

    def addSymbol(self, msig: SetcodeMultisig, value: int, symbolRTW: str):
        result = self._callFromMultisig(msig=msig, functionName="addSymbol", functionParams={"symbolRTW":symbolRTW}, value=value, flags=1)
        return result

    def addPair(self, msig: SetcodeMultisig, value: int, symbol1RTW: str, symbol2RTW: str):
        result = self._callFromMultisig(msig=msig, functionName="addPair", functionParams={"symbol1RTW":symbol1RTW, "symbol2RTW":symbol2RTW}, value=value, flags=1)
        return result

    def burn(self, msig: SetcodeMultisig, value: int, amount: int):
        result = self._callFromMultisig(msig=msig, functionName="burn", functionParams={"amount":amount}, value=value, flags=1)
        return result

    #========================================
    #
    def getPairAddress(self, symbol1RTW: str, symbol2RTW: str):
        result = self._run(functionName="getPairAddress", functionParams={"symbol1RTW":symbol1RTW, "symbol2RTW":symbol2RTW})
        return result

    def getCellContents(self, operation: int, price: int, slippage: int):
        result = self._run(functionName="getCellContents", functionParams={"operation":operation, "price":price, "slippage":slippage})
        return result

# ==============================================================================
# 
