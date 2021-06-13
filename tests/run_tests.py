#!/usr/bin/env python3

# ==============================================================================
# 
import freeton_utils
from   freeton_utils import *
import unittest
import time
import sys
from   pprint import pprint
from   contract_LiquidFTWallet import LiquidFTWallet
from   contract_LiquidFTRoot   import LiquidFTRoot
from   contract_DexFactory     import DexFactory
from   contract_SymbolPair     import SymbolPair

# ==============================================================================
#
TON            = 1000000000
SERVER_ADDRESS = "https://net.ton.dev"

# ==============================================================================
#
def getClient():
    return TonClient(config=ClientConfig(network=NetworkConfig(server_address=SERVER_ADDRESS)))

# ==============================================================================
# 
# Parse arguments and then clear them because UnitTest will @#$~!
for _, arg in enumerate(sys.argv[1:]):
    if arg == "--disable-giver":
        
        freeton_utils.USE_GIVER = False
        sys.argv.remove(arg)

    if arg == "--throw":
        
        freeton_utils.THROW = True
        sys.argv.remove(arg)

    if arg.startswith("http"):
        
        SERVER_ADDRESS = arg
        sys.argv.remove(arg)

    if arg.startswith("--msig-giver"):
        
        freeton_utils.MSIG_GIVER = arg[13:]
        sys.argv.remove(arg)

# ==============================================================================
# EXIT CODE FOR SINGLE-MESSAGE OPERATIONS
# we know we have only 1 internal message, that's why this wrapper has no filters
def _getAbiArray():
    return ["../bin/SetcodeMultisigWallet.abi.json", "../bin/DexFactory.abi.json", "../bin/SymbolPair.abi.json", "../bin/LiquidFTWallet.abi.json", "../bin/LiquidFTRoot.abi.json"]

def _getExitCode(msgIdArray):
    abiArray     = _getAbiArray()
    msgArray     = unwrapMessages(getClient(), msgIdArray, abiArray)
    if msgArray != "":
        realExitCode = msgArray[0]["TX_DETAILS"]["compute"]["exit_code"]
    else:
        realExitCode = -1
    return realExitCode  

# ==============================================================================
# 
root1 = LiquidFTRoot   (tonClient=getClient(), name="Candy", symbol="CND", decimals=9,  signer=generateSigner())
root2 = LiquidFTRoot   (tonClient=getClient(), name="Shop",  symbol="SHP", decimals=12, signer=generateSigner())
msig1 = SetcodeMultisig(tonClient=getClient())
msig2 = SetcodeMultisig(tonClient=getClient())

msigWallet1 = SetcodeMultisig(tonClient=getClient())
msigWallet2 = SetcodeMultisig(tonClient=getClient())

candyWallet1 = LiquidFTWallet(tonClient=getClient(), rootAddress=root1.ADDRESS, ownerAddress=msigWallet1.ADDRESS)
candyWallet2 = LiquidFTWallet(tonClient=getClient(), rootAddress=root1.ADDRESS, ownerAddress=msigWallet2.ADDRESS)

shopWallet1 = LiquidFTWallet(tonClient=getClient(), rootAddress=root2.ADDRESS, ownerAddress=msigWallet1.ADDRESS)
shopWallet2 = LiquidFTWallet(tonClient=getClient(), rootAddress=root2.ADDRESS, ownerAddress=msigWallet2.ADDRESS)

factory     = DexFactory     (tonClient=getClient(), signer=generateSigner())
pair1       = SymbolPair     (tonClient=getClient(), signer=generateSigner())
msigFactory = SetcodeMultisig(tonClient=getClient())


# ==============================================================================
# 
class Test_01_DeployRTW(unittest.TestCase):

    def test_0(self):
        print("\n\n----------------------------------------------------------------------")
        print("Running:", self.__class__.__name__)

    # 1. Giver
    def test_1(self):
        giverGive(getClient(), root1.ADDRESS, TON * 1)
        giverGive(getClient(), root2.ADDRESS, TON * 1)
        giverGive(getClient(), msig1.ADDRESS, TON * 1)
        giverGive(getClient(), msig2.ADDRESS, TON * 1)

    # 2. Deploy multisig
    def test_2(self):
        result = msig1.deploy()
        self.assertEqual(result[1]["errorCode"], 0)
        result = msig2.deploy()
        self.assertEqual(result[1]["errorCode"], 0)

    # 3. Deploy RTW
    def test_3(self):
        result = root1.deploy(icon="")
        self.assertEqual(result[1]["errorCode"], 0)
        result = root2.deploy(icon="")
        self.assertEqual(result[1]["errorCode"], 0)

    # 4. Get info
    def test_4(self):
        result = root1.getRootInfo()
        #print(result)
        result = root2.getRootInfo()
        #print(result)

    # 5. Cleanup
    def test_5(self):
        pass
        #result = msig1.destroy(addressDest = freeton_utils.giverGetAddress())
        #self.assertEqual(result[1]["errorCode"], 0)
        #result = msig2.destroy(addressDest = freeton_utils.giverGetAddress())
        #self.assertEqual(result[1]["errorCode"], 0)

# ==============================================================================
# 
class Test_02_DeployFactory(unittest.TestCase):

    def test_0(self):
        print("\n\n----------------------------------------------------------------------")
        print("Running:", self.__class__.__name__)

    # 1. Giver
    def test_1(self):
        giverGive(getClient(), msigFactory.ADDRESS, TON * 15)
        giverGive(getClient(), factory.ADDRESS,     TON * 1)

    # 2. Deploy msig
    def test_2(self):
        result = msigFactory.deploy()
        self.assertEqual(result[1]["errorCode"], 0)

    # 3. Deploy Factory
    def test_3(self):
        result = factory.deploy(ownerAddress=msigFactory.ADDRESS)
        self.assertEqual(result[1]["errorCode"], 0)

    # 4. Set TVCs
    def test_4(self):
        result = factory.setSymbolPairCode(msig=msigFactory, value=TON, code=getCodeFromTvc("../bin/SymbolPair.tvc"))
        result = factory.setLPWalletCode  (msig=msigFactory, value=TON, code=getCodeFromTvc("../bin/LiquidFTWallet.tvc"))
        result = factory.setRTWCode       (msig=msigFactory, value=TON, code=getCodeFromTvc("../bin/LiquidFTRoot.tvc"))
        result = factory.setTTWCode       (msig=msigFactory, value=TON, code=getCodeFromTvc("../bin/LiquidFTWallet.tvc"))

    # 5. Cleanup
    def test_5(self):
        pass
    
# ==============================================================================
# 
class Test_03_AddRTWToFactory(unittest.TestCase):

    def test_0(self):
        print("\n\n----------------------------------------------------------------------")
        print("Running:", self.__class__.__name__)

    # 1. Add
    def test_1(self):
        result = factory.addSymbol(msig=msigFactory, value=TON, symbolRTW=root1.ADDRESS)
        #msgArray = unwrapMessages(getClient(), result[0].transaction["out_msgs"], _getAbiArray())
        #pprint(msgArray)

        result = factory.addSymbol(msig=msigFactory, value=TON, symbolRTW=root2.ADDRESS)
        #msgArray = unwrapMessages(getClient(), result[0].transaction["out_msgs"], _getAbiArray())
        #pprint(msgArray)

    # 2. Cleanup
    def test_2(self):
        pass

# ==============================================================================
# 
class Test_04_CreatePair(unittest.TestCase):

    def test_0(self):
        print("\n\n----------------------------------------------------------------------")
        print("Running:", self.__class__.__name__)

    # 1. Create Pair
    def test_1(self):
        result = factory.addPair(msig=msigFactory, value=TON, symbol1RTW=root1.ADDRESS, symbol2RTW=root2.ADDRESS)
        #msgArray = unwrapMessages(getClient(), result[0].transaction["out_msgs"], _getAbiArray())
        #pprint(msgArray)

        result = factory.addSymbol(msig=msigFactory, value=TON, symbolRTW=root2.ADDRESS)
        #msgArray = unwrapMessages(getClient(), result[0].transaction["out_msgs"], _getAbiArray())
        #pprint(msgArray)

    # 2. Cleanup
    def test_2(self):
        pass

# ==============================================================================
# 
class Test_05_ProvideLiquidity(unittest.TestCase):

    def test_0(self):
        print("\n\n----------------------------------------------------------------------")
        print("Running:", self.__class__.__name__)

    # 1. Giver
    def test_1(self):
        giverGive(getClient(), msigWallet1.ADDRESS, TON * 5)
        giverGive(getClient(), msigWallet2.ADDRESS, TON * 5)

    # 2. Deploy msig
    def test_2(self):
        result = msigWallet1.deploy()
        self.assertEqual(result[1]["errorCode"], 0)
        result = msigWallet2.deploy()
        self.assertEqual(result[1]["errorCode"], 0)

    # 3. Create Wallets and provide liquidity
    def test_3(self):
        result = root1.createWallet(msig=msigWallet1, value=TON, ownerAddress=msigWallet1.ADDRESS, notifyOnReceiveAddress=ZERO_ADDRESS, tokensAmount=10000000000000)
        #msgArray = unwrapMessages(getClient(), result[0].transaction["out_msgs"], _getAbiArray())
        #pprint(msgArray)
        self.assertEqual(result[1]["errorCode"], 0)

        result = root2.createWallet(msig=msigWallet1, value=TON, ownerAddress=msigWallet1.ADDRESS, notifyOnReceiveAddress=ZERO_ADDRESS, tokensAmount=10000000000000)
        self.assertEqual(result[1]["errorCode"], 0)

        result = factory.getPairAddress(symbol1RTW=root1.ADDRESS, symbol2RTW=root2.ADDRESS)
        pair1.ADDRESS = result        

        lpWallet1 = LiquidFTWallet(tonClient=getClient(), rootAddress=pair1.ADDRESS, ownerAddress=msigWallet1.ADDRESS)
        pair1.createWallet(msig=msigWallet1, value=TON, ownerAddress=msigWallet1.ADDRESS, notifyOnReceiveAddress=ZERO_ADDRESS, tokensAmount=0)

        cell = factory.getCellContents(operation=1, price=0, slippage=0) # DEPOSIT_LIQUIDITY
        result = candyWallet1.transfer(msig=msigWallet1, value=100000000, amount=5000000000000, targetOwnerAddress=pair1.ADDRESS, initiatorAddress=msigWallet1.ADDRESS, notifyAddress=ZERO_ADDRESS, body=cell)
        #msgArray = unwrapMessages(getClient(), result[0].transaction["out_msgs"], _getAbiArray())
        #pprint(msgArray)
        result = shopWallet1.transfer(msig=msigWallet1, value=100000000, amount=5000000000000, targetOwnerAddress=pair1.ADDRESS, initiatorAddress=msigWallet1.ADDRESS, notifyAddress=ZERO_ADDRESS, body=cell)
        
        result = pair1.depositLiquidity(msig=msigWallet1, value=TON, amountSymbol1=2000000000000, amountSymbol2=2000000000000, slippage=100)
        #msgArray = unwrapMessages(getClient(), result[0].transaction["out_msgs"], _getAbiArray())
        #pprint(msgArray)

        result = pair1.collectLiquidityLeftovers(msig=msigWallet1, value=TON)
        msgArray = unwrapMessages(getClient(), result[0].transaction["out_msgs"], _getAbiArray())
        pprint(msgArray)

    # 4. Provide liquidity
    def test_4(self):
        result = factory.setSymbolPairCode(msig=msigFactory, value=TON, code=getCodeFromTvc("../bin/SymbolPair.tvc"))
        result = factory.setLPWalletCode  (msig=msigFactory, value=TON, code=getCodeFromTvc("../bin/LiquidFTWallet.tvc"))
        result = factory.setRTWCode       (msig=msigFactory, value=TON, code=getCodeFromTvc("../bin/LiquidFTRoot.tvc"))
        result = factory.setTTWCode       (msig=msigFactory, value=TON, code=getCodeFromTvc("../bin/LiquidFTWallet.tvc"))

    # 5. Cleanup
    def test_5(self):
        pass

# ==============================================================================
# 
unittest.main()
