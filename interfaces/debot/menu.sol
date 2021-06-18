pragma ton-solidity >= 0.42.0;
pragma AbiHeader time;
pragma AbiHeader pubkey;
pragma AbiHeader expire;

//================================================================================
//
struct MenuItem 
{
    string title;
    string description;
    uint32 handlerId;
}

//================================================================================
//
interface IMenu 
{
    function select(string title, string description, MenuItem[] items) external returns (uint32 index);
}

//================================================================================
//
library Menu 
{
    uint256 constant ID = 0xac1a4d3ecea232e49783df4a23a81823cdca3205dc58cd20c4db259c25605b48;
    int8    constant DEBOT_WC = -31;
    address constant addr     = address.makeAddrStd(DEBOT_WC, ID);

    function select(string title, string description, MenuItem[] items) public pure 
    {
        IMenu(addr).select(title, description, items);
    }
}

//================================================================================
//