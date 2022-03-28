pragma solidity >=0.5.0;

interface IFSwapFactory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;

    function setBaseToken(address pair, address addr) external;
    function getBaseToken(address pair) external view returns (address token);
    function setRelation(address pair, address addr) external;
    function getRelation(address pair) external view returns (address _relation);
    function setDefRelation(address addr) external;
    function setDefBaseToken(address _addr) external;
    function getDefFeeTo(address pair) external view returns (address _fee);
    function setDefFeeTo(address addr) external;
}
