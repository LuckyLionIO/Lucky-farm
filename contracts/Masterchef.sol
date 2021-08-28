pragma solidity >=0.8.0; //SPDX-License-Identifier: UNLICENSED

import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./LuckyToken.sol";

contract MasterChef is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;         // How many LP tokens the user has provided.
        uint256 rewardDebt;     // Reward debt. See explanation below.
        uint256 rewardLockedUp;  // Reward locked up.
        //
        // We do some fancy math here. Basically, any point in time, the amount of luckys
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accluckyPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accluckyPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken;           // Address of LP token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. luckys to distribute per block.
        uint256 lastRewardBlock;  // Last block number that luckys distribution occurs.
        uint256 accLuckyPerShare;   // Accumulated luckys per share, times 1e12. See below.
        uint16 depositFeeBP;      // Deposit fee in basis points
        uint256 harvestTimestamp;  // Harvest interval in unixtimestamp
    }

    // The lucky TOKEN!
    LuckyToken public lucky;
    // Dev address.
    address public devAddress;
    // Deposit Fee address
    address private feeAddress= 0x768a9C2109D810CD460E65319e1209723b59650B;
    //owner's address
    address private Owner = 0x49aE5637252FD7d716484E6D9488596322653d80;
    // lucky tokens created per block.
    uint256 public luckyPerBlock;
    // Bonus muliplier for early lucky makers.
    uint256 public constant BONUS_MULTIPLIER = 1;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when lucky mining starts.
    uint256 public startBlock;
    // Total locked up rewards
    uint256 public totalLockedUpRewards;
    uint256 private mintedForDev;
    uint256 private devMintingRatio;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmissionRateUpdated(address indexed caller, uint256 previousAmount, uint256 newAmount);
    event RewardLockedUp(address indexed user, uint256 indexed pid, uint256 amountLockedUp);

    constructor(
        LuckyToken _lucky,
        uint256 _startBlock,
        uint256 _luckyPerBlock,
        IERC20 BNB,
        IERC20 LUCKYBNB,
        IERC20 LUCKYBUSD,
        IERC20 BNBBUSD,
        IERC20 USDTBUSD
        
    ) {
        lucky = _lucky;
        startBlock = _startBlock;
        luckyPerBlock = _luckyPerBlock;

        devAddress = msg.sender;
        transferOwnership(Owner);
        
        //hardcode to set the lucky sole pool to be the first pool.
        poolInfo.push(PoolInfo({
            lpToken: _lucky,
            allocPoint: 650,
            lastRewardBlock: startBlock,
            accLuckyPerShare: 0,
            depositFeeBP : 0,
            harvestTimestamp: block.timestamp +  8 hours
        }));
        
        //LUCKYBUSD
        poolInfo.push(PoolInfo({
            lpToken: LUCKYBUSD,
            allocPoint: 3000,
            lastRewardBlock: startBlock,
            accLuckyPerShare: 0,
            depositFeeBP : 0,
            harvestTimestamp: block.timestamp +  8 hours
        }));
        
        //lucky-BNB
        poolInfo.push(PoolInfo({
            lpToken: LUCKYBNB,
            allocPoint: 4000,
            lastRewardBlock: startBlock,
            accLuckyPerShare: 0,
            depositFeeBP : 0,
            harvestTimestamp: block.timestamp +  8 hours
        }));

        //BNB
        poolInfo.push(PoolInfo({
            lpToken: BNB,
            allocPoint: 130,
            lastRewardBlock: startBlock,
            accLuckyPerShare: 0,
            depositFeeBP : 200,
            harvestTimestamp: block.timestamp +  8 hours
        }));
        
        //BNBBUSD
        poolInfo.push(PoolInfo({
            lpToken: BNBBUSD,
            allocPoint: 800,
            lastRewardBlock: startBlock,
            accLuckyPerShare: 0,
            depositFeeBP : 200,
            harvestTimestamp: block.timestamp +  8 hours
        }));
        
        //USDTBUSD
        poolInfo.push(PoolInfo({
            lpToken: USDTBUSD,
            allocPoint: 200,
            lastRewardBlock: startBlock,
            accLuckyPerShare: 0,
            depositFeeBP : 200,
            harvestTimestamp: block.timestamp +  8 hours
        }));
        
        //how much dev will get from minting
        devMintingRatio = 10;
        
        //change according to the sum of initial allocpoint.
        totalAllocPoint = 650+3000+4000+130+800+200;
    

    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(uint256 _allocPoint, IERC20 _lpToken, uint16 _depositFeeBP, uint256 _harvestTimestamp, bool _withUpdate) public onlyOwner {
        require(_depositFeeBP <= 10000, "add: invalid deposit fee basis points");
        require(_harvestTimestamp >= block.timestamp, "add: invalid harvest interval");
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            allocPoint: _allocPoint,
            lastRewardBlock: lastRewardBlock,
            accLuckyPerShare: 0,
            depositFeeBP: _depositFeeBP,
            harvestTimestamp: _harvestTimestamp
        }));
    }

    // Update the given pool's lucky allocation point and deposit fee. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, uint16 _depositFeeBP, uint256 _harvestTimestamp, bool _withUpdate) public onlyOwner {
        require(_depositFeeBP <= 10000, "set: invalid deposit fee basis points");
        require(_harvestTimestamp >= block.timestamp, "set: invalid harvest interval");
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
        poolInfo[_pid].depositFeeBP = _depositFeeBP;
        poolInfo[_pid].harvestTimestamp = _harvestTimestamp;
        
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public pure returns (uint256) {
        return _to.sub(_from).mul(BONUS_MULTIPLIER);
    }

    // View function to see pending luckys on frontend.
    function pendingLucky(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accLuckyPerShare = pool.accLuckyPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 luckyReward = multiplier.mul(luckyPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accLuckyPerShare = accLuckyPerShare.add(luckyReward.mul(1e12).div(lpSupply));
        }
        uint256 pending = user.amount.mul(accLuckyPerShare).div(1e12).sub(user.rewardDebt);
        return pending.add(user.rewardLockedUp);
    }

    // View function to see if user can harvest luckys.
    function canHarvest(uint256 _pid) public view returns (bool) {
        //UserInfo storage user = userInfo[_pid][_user];
        PoolInfo storage pool = poolInfo[_pid];
        return block.timestamp >= pool.harvestTimestamp;
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0 || pool.allocPoint == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 luckyReward = multiplier.mul(luckyPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
        //new one 
        // check at final to mint exact Lucky to complete the round 9 million and 100 millions totalsupply 
        uint256 luckyRewardForDev = luckyReward.mul(devMintingRatio).div(74);
        lucky.mint(devAddress, luckyRewardForDev); //what number is this 30 >> 70   x/100 *74 = 9 >> x= 9/74*100
        mintedForDev = mintedForDev.add(luckyRewardForDev);
        lucky.mint(address(this), luckyReward); //
        pool.accLuckyPerShare = pool.accLuckyPerShare.add(luckyReward.mul(1e12).div(lpSupply));
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to MasterChef for lucky allocation.
    function deposit(uint256 _pid, uint256 _amount) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);

        payOrLockupPendingLucky(_pid);
        if (_amount > 0) {
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            
            if (pool.depositFeeBP > 0) {
                uint256 depositFee = _amount.mul(pool.depositFeeBP).div(10000);
                pool.lpToken.safeTransfer(feeAddress, depositFee);
                user.amount = user.amount.add(_amount).sub(depositFee);
            } else {
                user.amount = user.amount.add(_amount);
            }
        }
        user.rewardDebt = user.amount.mul(pool.accLuckyPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        payOrLockupPendingLucky(_pid);
        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accLuckyPerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        user.rewardLockedUp = 0;
        pool.lpToken.safeTransfer(address(msg.sender), amount);
        emit EmergencyWithdraw(msg.sender, _pid, amount);
    }

    // Pay or lockup pending luckys.
    function payOrLockupPendingLucky(uint256 _pid) internal {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        // if (user.nextHarvestUntil == 0) {
        //     user.nextHarvestUntil = block.timestamp.add(pool.harvestTimestamp);
        // } 

        uint256 pending = user.amount.mul(pool.accLuckyPerShare).div(1e12).sub(user.rewardDebt);
        if (canHarvest(_pid)) {
            if (pending > 0 || user.rewardLockedUp > 0) {
                uint256 totalRewards = pending.add(user.rewardLockedUp);

                // reset lockup
                totalLockedUpRewards = totalLockedUpRewards.sub(user.rewardLockedUp);
                user.rewardLockedUp = 0;
                //user.nextHarvestUntil = block.timestamp.add(pool.harvestTimestamp);

                // send rewards
                safeLuckyTransfer(msg.sender, totalRewards);
                //payReferralCommission(msg.sender, totalRewards);
            }
        } else if (pending > 0) {
            user.rewardLockedUp = user.rewardLockedUp.add(pending);
            totalLockedUpRewards = totalLockedUpRewards.add(pending);
            emit RewardLockedUp(msg.sender, _pid, pending);
        }
    }

    // Safe lucky transfer function, just in case if rounding error causes pool to not have enough luckys.
    function safeLuckyTransfer(address _to, uint256 _amount) internal {
        uint256 luckyBal = lucky.balanceOf(address(this));
        if (_amount > luckyBal) {
            lucky.transfer(_to, luckyBal);
        } else {
            lucky.transfer(_to, _amount);
        }
    }

    // Update dev address by the previous dev.
    function setDevAddress(address _devAddress) public onlyOwner{
        //require(msg.sender == devAddress, "setDevAddress: FORBIDDEN");
        require(_devAddress != address(0), "setDevAddress: ZERO");
        devAddress = _devAddress;
    }

    function setFeeAddress(address _feeAddress) public onlyOwner {
        //require(msg.sender == feeAddress, "setFeeAddress: FORBIDDEN");
        require(_feeAddress != address(0), "setFeeAddress: ZERO");
        feeAddress = _feeAddress;
    }

    // Pancake has to add hidden dummy pools in order to alter the emission, here we make it simple and transparent to all.
    function updateEmissionRate(uint256 _luckyPerBlock) public onlyOwner {
        massUpdatePools();
        emit EmissionRateUpdated(msg.sender, luckyPerBlock, _luckyPerBlock);
        //this is the new one
        uint256 prevLuckyPerBlock = luckyPerBlock;
        if (prevLuckyPerBlock !=_luckyPerBlock){
            luckyPerBlock = _luckyPerBlock;
        }
    }
    function getBlockNumber () public view returns(uint256){
        return block.number;
    }

}
