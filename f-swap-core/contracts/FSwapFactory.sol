pragma solidity =0.5.16;

import './interfaces/IFSwapFactory.sol';
import './FSwapPair.sol';

contract FSwapFactory is IFSwapFactory {
    bytes32 public constant INIT_CODE_PAIR_HASH = keccak256(abi.encodePacked(type(FSwapPair).creationCode));

    address public feeTo;
    address public feeToSetter;

    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    mapping(address => address) public baseToken;

    mapping(address => address) public relation;

    mapping(address => address) public pairFee;

    address public def_relation;
    address public def_baseToken = 0x55d398326f99059fF775485246999027B3197955;
    address public def_fee_to = 0xe8a374c386d94B9B9d8fEB801aeC1EE44aad06eC;

    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    constructor(address _feeToSetter) public {
        feeToSetter = _feeToSetter;
    }

    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB, 'FSwap: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'FSwap: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'FSwap: PAIR_EXISTS'); // single check is sufficient
        bytes memory bytecode = type(FSwapPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        IFSwapPair(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter, 'FSwap: FORBIDDEN');
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, 'FSwap: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }

    function setBaseToken(address pair, address addr) external {
        require(msg.sender == feeToSetter, 'FSwap: FORBIDDEN');
        baseToken[pair] = addr;
    }

    function getBaseToken(address _addr) external view returns (address token) {
        token = baseToken[_addr];
        if (token == address(0)) {
            token = def_baseToken;
        }
    }

    function setDefBaseToken(address _addr) external {
        require(msg.sender == feeToSetter, 'FSwap: FORBIDDEN');
        def_baseToken = _addr;
    }

    function setRelation(address pair, address addr) external {
        require(msg.sender == feeToSetter, 'FSwap: FORBIDDEN');
        relation[pair] = addr;
    }

    function getRelation(address pair) external view returns (address _relation) {
        _relation = relation[pair];
        if (_relation == address(0)) {
            _relation = def_relation;
        }
    }

    function setDefRelation(address addr) external {
        require(msg.sender == feeToSetter, 'FSwap: FORBIDDEN');
        def_relation = addr;
    }

    function getDefFeeTo(address pair) external view returns (address _fee) {
        _fee = pairFee[pair];
        if (_fee == address(0)) {
            _fee = def_fee_to;
        }
    }

    function setDefFeeTo(address addr) external {
        require(msg.sender == feeToSetter, 'FSwap: FORBIDDEN');
        def_fee_to = addr;
    }
}
