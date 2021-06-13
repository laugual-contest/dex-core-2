#!/usr/bin/env python3

# ==============================================================================
#
import freeton_utils
from   freeton_utils import *

class LiquidFTWallet(object):
    def __init__(self, tonClient: TonClient, rootAddress: str, ownerAddress: str, signer: Signer = None):
        self.SIGNER      = generateSigner() if signer is None else signer
        self.TONCLIENT   = tonClient
        self.ABI         = "../bin/LiquidFTWallet.abi.json"
        self.TVC         = "../bin/LiquidFTWallet.tvc"
        self.CODE        = getCodeFromTvc(self.TVC)
        self.CONSTRUCTOR = {}
        self.INITDATA    = {"_rootAddress":rootAddress,"_ownerAddress":ownerAddress}
        self.PUBKEY      = ZERO_PUBKEY
        self.ADDRESS     = getAddressZeroPubkey(abiPath=self.ABI, tvcPath=self.TVC, initialData=self.INITDATA)

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

    def transfer(self, msig: SetcodeMultisig, value: int, amount: int, targetOwnerAddress: str, initiatorAddress: str, notifyAddress: str, body: str):
        result = self._callFromMultisig(msig=msig, functionName="transfer", functionParams={"amount":amount, "targetOwnerAddress":targetOwnerAddress, "initiatorAddress":initiatorAddress, "notifyAddress":notifyAddress, "body":body}, value=value, flags=1)
        return result

    def burn(self, msig: SetcodeMultisig, value: int, amount: int):
        result = self._callFromMultisig(msig=msig, functionName="burn", functionParams={"amount":amount}, value=value, flags=1)
        return result

    def getBalance(self):
        result = self._run(functionName="getBalance", functionParams={})
        return result


# ==============================================================================
# 
