// SPDX-License-Identifier: MIT

pragma solidity >=0.5.0 <0.8.0;

import "./library/k.sol";
import "./interfaces/IERC20.sol";

contract RelationStorage is KStoragePayable {

    address internal rootAddress;

    uint public totalAddresses;

    uint public base = 10000e18;

    address public fansToken;

    mapping (address => address payable) internal _recommerMapping;
    mapping (address => address[]) internal _recommerList;
}

contract Relation is RelationStorage {

    constructor(address _fansToken) public {
        fansToken = _fansToken;
        rootAddress = address(this);
        _recommerMapping[rootAddress] = address(0xdeaddead);
    }

    function recommendInfo(address owner) external view returns(bool v, address recommend) {
        return(_recommerMapping[owner] != address(0),_recommerMapping[owner]);
    }

    function addRelationEx(address recommer) external KRejectContractCall returns (bool) {
        require(recommer != msg.sender,"your_self");

        require(_recommerMapping[msg.sender] == address(0x0),"binded");

        require(recommer == rootAddress || _recommerMapping[recommer] != address(0x0),"p_not_bind");

        if (recommer != rootAddress) {
            uint balance = IERC20(fansToken).balanceOf(recommer);
            require(balance >= base, "token not enough");
        }

        totalAddresses++;

        _recommerMapping[msg.sender] = address(uint160(recommer));
        _recommerList[recommer].push(msg.sender);

        return true;
    }

    function getRecommer(address owner) external view returns(address){
        address recommer = _recommerMapping[owner];
        if ( recommer != rootAddress ) return recommer;
        return address(0x0);
    }

    function getChilds(address owner)external view returns(address[] memory){
        return _recommerList[owner];
    }

    function setToken(address _token) external KOwnerOnly {
        fansToken = _token;
    }

    function setBase(uint _num) external KOwnerOnly {
        base = _num;
    }

    function takeOutTokenInCase(address _token, uint256 _amount, address _to) external KOwnerOnly {
        IERC20(_token).transfer(_to, _amount);
    }
}