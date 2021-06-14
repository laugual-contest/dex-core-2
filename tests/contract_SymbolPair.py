#!/usr/bin/env python3

# ==============================================================================
#
import freeton_utils
from   freeton_utils import *

class SymbolPair(object):
    def __init__(self, tonClient: TonClient, signer: Signer):
        self.SIGNER      = generateSigner() if signer is None else signer
        self.TONCLIENT   = tonClient
        self.ABI         = "../bin/SymbolPair.abi.json"
        self.TVC         = "../bin/SymbolPair.tvc"
        self.ADDRESS     = ZERO_ADDRESS
        #self.CODE        = getCodeFromTvc(self.TVC)
        #self.CONSTRUCTOR = {}
        #self.INITDATA    = {}
        #self.PUBKEY      = self.SIGNER.keys.public
        #self.ADDRESS     = getAddress(abiPath=self.ABI, tvcPath=self.TVC, signer=signer, initialPubkey=self.PUBKEY, initialData=self.INITDATA)

    #def deploy(self, ownerAddress: str):
    #    self.CONSTRUCTOR = {"ownerAddress":ownerAddress}
    #    result = deployContract(tonClient=self.TONCLIENT, abiPath=self.ABI, tvcPath=self.TVC, constructorInput=self.CONSTRUCTOR, initialData=self.INITDATA, signer=self.SIGNER, initialPubkey=self.PUBKEY)
    #    return result
        
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
    def depositLiquidity(self, msig: SetcodeMultisig, value: int, amountSymbol1: int, amountSymbol2: int, slippage: int):
        result = self._callFromMultisig(msig=msig, functionName="depositLiquidity", functionParams={"amountSymbol1":amountSymbol1, "amountSymbol2":amountSymbol2, "slippage":slippage}, value=value, flags=1)
        return result
    
    def createWallet(self, msig: SetcodeMultisig, value: int, ownerAddress: str, notifyOnReceiveAddress: str, tokensAmount: int):
        result = self._callFromMultisig(msig=msig, functionName="createWallet", functionParams={"ownerAddress":ownerAddress, "notifyOnReceiveAddress":notifyOnReceiveAddress, "tokensAmount":tokensAmount}, value=value, flags=1)
        return result

    def collectLiquidityLeftovers(self, msig: SetcodeMultisig, value: int):
        result = self._callFromMultisig(msig=msig, functionName="collectLiquidityLeftovers", functionParams={}, value=value, flags=1)
        return result

    #========================================
    #
    def getPrice(self, symbolSellRTW: str, amountToGive: int):
        result = self._run(functionName="getPrice", functionParams={"symbolSellRTW":symbolSellRTW, "amountToGive":amountToGive})
        return result


# ==============================================================================
# 
