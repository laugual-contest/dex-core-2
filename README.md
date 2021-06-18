# LiquiSOR DEX

## Description
LP AMM decentralized exchange for Free TON.

Full information about TRC-6 fungible tokens can be found here: https://github.com/laugual/liquid-ft

DEVNET Factory address: `0:001027da37f0cf6fc62e4b684d6131b5ea048e056e88d2c7f954a323ea112069`;

DEVNET DeBot   address: `0:6d9982a8c49531218db59af8eb8803cd77e757536004ee481c41f1e6a7e07144`;

## Modules
* `LiquidFTWallet.sol` - TRC-6 fungible token wallet, FEATURES:
    * Respects asynchronous nature of Free TON;
    * Only internal owners (addresses);
    * Automatic balance management - no need to worry about wallet contract balance;
    * Customizable token events on send/receive;
    * No allowances (no need for them with this design);
    * Only 2 main functions, `transfer` and `receiveTransfer`, no more confusion;
* `LiquidFTRoot.sol` - TRC-6 fungible token wallet root, FEATURES:
    * Respects asynchronous nature of Free TON;
    * Only internal owners (addresses);
    * Automatic balance management - no need to worry about wallet contract balance;
* `SymbolPair.sol` - Pair pool for trading; FEATURES:
    * Deposit liquidity and earn interest (on fees);
    * Withdraw liquidity at any time;
    * Swap tokens;
* `DexFactory.sol` - DEX Factory that stores and manages all pairs/pools; FEATURES:
    * Create new TRC-6 Symbols (automatically added to DEX);
    * Add existing Symbols to DEX; anyone can add existing Symbol, Symbol validity is verified by RTW callback;
    * Create new Symbol Pairs; anyone can create new SymbolPair if it doesn't exist;
    * Change Symbol Pair LP fee;
* `DexDebot.sol` - DexFactory DeBot; FEATURES:
    * All `DexFactory` features except creating new TRC-6 Symbols (TRC-6 RTW stores Symbol icon and it can't be set in DeBot);
    * All `SymbolPair` features;

## Testing

```
cd tests
./run_tests.py http://127.0.0.1
```
