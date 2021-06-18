#!/usr/bin/env python3

# ==============================================================================
#
import freeton_utils
from   freeton_utils import *

class DexDebot(object):
    def __init__(self, tonClient: TonClient, ownerAddress: str, signer: Signer):
        self.SIGNER      = generateSigner() if signer is None else signer
        self.TONCLIENT   = tonClient
        self.ABI         = "../bin/DexDebot.abi.json"
        self.TVC         = "../bin/DexDebot.tvc"
        self.CODE        = getCodeFromTvc(self.TVC)
        self.CONSTRUCTOR = {"ownerAddress":ownerAddress}
        self.INITDATA    = {}
        self.PUBKEY      = self.SIGNER.keys.public
        self.ADDRESS     = getAddress(abiPath=self.ABI, tvcPath=self.TVC, signer=signer, initialPubkey=self.PUBKEY, initialData=self.INITDATA)

    def deploy(self):
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
    def setABI(self, msig: SetcodeMultisig, value: int, dabi: str):
        result = self._callFromMultisig(msig=msig, functionName="setABI", functionParams={"dabi":dabi}, value=value, flags=1)
        return result

    def setFactoryAddress(self, msig: SetcodeMultisig, value: int, factoryAddress: str):
        result = self._callFromMultisig(msig=msig, functionName="setFactoryAddress", functionParams={"factoryAddress":factoryAddress}, value=value, flags=1)
        return result


# ==============================================================================
# 
