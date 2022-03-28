// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.5.0 <0.8.0;

contract KOwnerableUpgradeable {

    address[] internal _authAddress;

    address[] public KContractOwners;

    bool private _call_locked;

    constructor() public {
        KContractOwners.push(msg.sender);
        _authAddress.push(msg.sender);
    }

    function KAuthAddresses() external view returns (address[] memory) {
        return _authAddress;
    }

    
    function KAddAuthAddress(address auther) external KOwnerOnly {
        _authAddress.push(auther);
    }

    
    function KDelAuthAddress(address auther) external KOwnerOnly {
        for (uint i = 0; i < _authAddress.length; i++) {
            if (_authAddress[i] == auther) {
                for (uint j = 0; j < _authAddress.length - 1; j++) {
                    _authAddress[j] = _authAddress[j+1];
                }
                delete _authAddress[_authAddress.length - 1];
                _authAddress.pop();
                return ;
            }
        }
    }

    modifier KOwnerOnly() {
        bool exist = false;
        for ( uint i = 0; i < KContractOwners.length; i++ ) {
            if ( KContractOwners[i] == msg.sender ) {
                exist = true;
                break;
            }
        }
        require(exist, 'NotAuther'); _;
    }

    modifier KDemocracyOnly() {
        bool exist = false;
        for ( uint i = 0; i < KContractOwners.length; i++ ) {
            if ( KContractOwners[i] == msg.sender ) {
                exist = true;
                break;
            }
        }
        require( exist , 'NotAuther'); _;
    }

    modifier KRejectContractCall() {
        uint256 size;
        address payable safeAddr = msg.sender;
        assembly {size := extcodesize(safeAddr)}
        require( size == 0, "Sender Is Contract" );
        _;
    }
}

contract KStoragePayable is KOwnerableUpgradeable {

    address public KImplementAddress;

    function SetKImplementAddress(address impl) external KDemocracyOnly {
        KImplementAddress = impl;
    }

    function () external payable {
        address impl_address = KImplementAddress;
        assembly {

            if eq(calldatasize(), 0) {
                return(0, 0)
            }

            calldatacopy(0x0, 0x0, calldatasize())
            let success := delegatecall(gas(), impl_address, 0x0, calldatasize(), 0, 0)
            let retSz := returndatasize()
            returndatacopy(0, 0, retSz)
            switch success
            case 0 {
                revert(0, retSz)
            }
            default {
                return(0, retSz)
            }
        }
    }
}
