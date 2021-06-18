pragma ton-solidity >= 0.42.0;
pragma AbiHeader time;
pragma AbiHeader pubkey;
pragma AbiHeader expire;

//================================================================================
//
interface IAddressInput 
{
	function get(uint32 answerId, string prompt) external returns (address value);
}

//================================================================================
//
library AddressInput 
{
    uint256 constant ID       = 0xd7ed1bd8e6230871116f4522e58df0a93c5520c56f4ade23ef3d8919a984653b;
    int8    constant DEBOT_WC = -31;
    address constant addr     = address.makeAddrStd(DEBOT_WC, ID);

    function get(uint32 answerId, string prompt) public pure 
    {
        IAddressInput(addr).get(answerId, prompt);
    }
}

//================================================================================
//