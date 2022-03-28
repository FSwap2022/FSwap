pragma solidity >=0.5.0;

interface IRelation {
  function recommendInfo(address owner) external view returns(bool v, address recommend);
}