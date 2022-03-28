/**
 *Submitted for verification at BscScan.com on 2021-10-04
*/

// SPDX-License-Identifier: MIT

pragma solidity =0.6.12;

import './interfaces/IBEP20.sol';
import './libs/Ownable.sol';
import './libs/SafeMath.sol';
import './libs/TransferHelper.sol';

interface IEarnHolder {
    function safeCakeTransfer(address _to, uint256 _amount) external;
}

interface IRelation {
    function recommendInfo(address owner) external view returns(bool v, address recommend);
}

interface IMigratorChef {
    function migrate(IBEP20 token) external returns (IBEP20);
}

contract MasterChef is Ownable {
    using SafeMath for uint256;

    // Info of each user.
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }

    // Info of each pool.
    struct PoolInfo {
        IBEP20 lpToken;
        IBEP20 earningToken;
        IEarnHolder earnHolder;
        uint256 lastRewardBlock;
        uint256 accCakePerShare;
        uint256 rewardPerBlock;
    }

    uint256 public BONUS_MULTIPLIER = 1;

    IMigratorChef public migrator;

    IRelation public relation;
    address public rewardFee;
    uint256 public feeRate = 25;
    uint256 public recommendRate = 40;
    uint256 public rewardRate = 60;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    // The block number when CAKE mining starts.
    uint256 public startBlock;

    mapping(IBEP20 => bool) public poolExistence;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    modifier validatePoolByPid(uint256 _pid) {
        require (_pid < poolInfo . length , "Pool does not exist") ;
        _;
    }

    modifier nonDuplicated(IBEP20 _lpToken) {
        require(poolExistence[_lpToken] == false, "nonDuplicated: duplicated");
        _;
    }

    constructor(
        address _relation,
        address _rewardFee,
        uint256 _startBlock
    ) public {
        relation = IRelation(_relation);
        rewardFee = _rewardFee;
        startBlock = _startBlock;
    }

    function updateMultiplier(uint256 multiplierNumber) public onlyOwner {
        BONUS_MULTIPLIER = multiplierNumber;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    function add(IBEP20 _lpToken, IBEP20 _earningToken, IEarnHolder _earnHolder, uint256 _rewardPerBlock, bool _withUpdate) public onlyOwner nonDuplicated(_lpToken) {
        if (_withUpdate) {
            massUpdatePools();
        }
        poolExistence[_lpToken] = true;
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            earningToken: _earningToken,
            earnHolder: _earnHolder,
            lastRewardBlock: lastRewardBlock,
            accCakePerShare: 0,
            rewardPerBlock: _rewardPerBlock
        }));
    }

    function set(uint256 _pid, uint256 _rewardPerBlock, bool _withUpdate) public onlyOwner validatePoolByPid(_pid) {
        if (_withUpdate) {
            massUpdatePools();
        }
        PoolInfo storage pool = poolInfo[_pid];
        if (_rewardPerBlock != pool.rewardPerBlock) {
            pool.rewardPerBlock = _rewardPerBlock;
        }
    }

    // Set the migrator contract. Can only be called by the owner.
    function setMigrator(IMigratorChef _migrator) public onlyOwner {
        migrator = _migrator;
    }

    // Migrate lp token to another lp contract. Can be called by anyone. We trust that migrator contract is good.
    function migrate(uint256 _pid) public validatePoolByPid(_pid) {
        require(address(migrator) != address(0), "migrate: no migrator");
        PoolInfo storage pool = poolInfo[_pid];
        IBEP20 lpToken = pool.lpToken;
        uint256 bal = lpToken.balanceOf(address(this));
        TransferHelper.safeApprove(address(lpToken), address(migrator), bal);
        IBEP20 newLpToken = migrator.migrate(lpToken);
        require(bal == newLpToken.balanceOf(address(this)), "migrate: bad");
        pool.lpToken = newLpToken;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        return _to.sub(_from).mul(BONUS_MULTIPLIER);
    }

    function pendingCake(uint256 _pid, address _user) external view validatePoolByPid(_pid) returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accCakePerShare = pool.accCakePerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 cakeReward = multiplier.mul(pool.rewardPerBlock);
            accCakePerShare = accCakePerShare.add(cakeReward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accCakePerShare).div(1e12).sub(user.rewardDebt);
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    function updatePool(uint256 _pid) public validatePoolByPid(_pid) {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 cakeReward = multiplier.mul(pool.rewardPerBlock);
        pool.accCakePerShare = pool.accCakePerShare.add(cakeReward.mul(1e12).div(lpSupply));
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to MasterChef for token allocation.
    function deposit(uint256 _pid, uint256 _amount) public validatePoolByPid(_pid) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accCakePerShare).div(1e12).sub(user.rewardDebt);
            if (pending > 0) {
                uint256 _fee = takeLpFee(pool.earnHolder, msg.sender, pending);
                safeCakeTransfer(pool.earnHolder, msg.sender, pending.sub(_fee));
            }
        }
        if (_amount > 0) {
            TransferHelper.safeTransferFrom(address(pool.lpToken), address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(pool.accCakePerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public validatePoolByPid(_pid) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");

        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accCakePerShare).div(1e12).sub(user.rewardDebt);
        if (pending > 0) {
            uint256 _fee = takeLpFee(pool.earnHolder, msg.sender, pending);
            safeCakeTransfer(pool.earnHolder, msg.sender, pending.sub(_fee));
        }
        if(_amount > 0) {
            user.amount = user.amount.sub(_amount);
            TransferHelper.safeTransfer(address(pool.lpToken), address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accCakePerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public validatePoolByPid(_pid) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        TransferHelper.safeTransfer(address(pool.lpToken), address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    function takeLpFee(IEarnHolder _earnHolder, address from, uint256 amount) internal returns(uint256 fee) {
        if (amount > 0 && address(relation) != address(0)) {
            (bool v, address recommend) = relation.recommendInfo(from);
            fee = amount.mul(feeRate) / 10000;
            if (v) {
                safeCakeTransfer(_earnHolder, recommend, fee.mul(recommendRate) / 100);
                safeCakeTransfer(_earnHolder, rewardFee, fee.mul(rewardRate) / 100);
            } else {
                safeCakeTransfer(_earnHolder, rewardFee, fee.mul(100) / 100);
            }
        }
    }

    // Safe token transfer function, just in case if rounding error causes pool to not have enough CAKEs.
    function safeCakeTransfer(IEarnHolder _earnHolder, address _to, uint256 _amount) internal {
        _earnHolder.safeCakeTransfer(_to, _amount);
    }

    function setRelation(IRelation _relation) external onlyOwner {
        relation = _relation;
    }

    function setRewardFee(address _addr) external onlyOwner {
        rewardFee = _addr;
    }

    function setFeeRate(uint256 _rate) external onlyOwner {
        feeRate = _rate;
    }

    function setRecommendRate(uint256 _rate) external onlyOwner {
        recommendRate = _rate;
    }

    function setRewardRate(uint256 _rate) external onlyOwner {
        rewardRate = _rate;
    }
}
