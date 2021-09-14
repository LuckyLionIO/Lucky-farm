pragma solidity 0.8.7; //SPDX-License-Identifier: UNLICENSED

import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./LuckyToken.sol";
import "./SyrupBar.sol";
interface IMigratorChef {
    // Perform LP token migration from legacy LuckyPool to the new one.
    // Take the current LP token address and return the new LP token address.
    // Migrator should have full access to the caller's LP token.
    // Return the new LP token address.
    //
    // XXX Migrator must have allowance access to PancakeSwap LP tokens.
    // CakeSwap must mint EXACTLY the same amount of CakeSwap LP tokens or
    // else something bad will happen. Traditional PancakeSwap does not
    // do that so be careful!
    function migrate(IERC20 token) external returns (IERC20);
    }
    
// XXX decrease pool to 2 and not have have deposit fee anymore.    
contract MasterChef is Ownable, ReentrancyGuard {
    using SafeMath for uint256;// @note NO CHANGE
    using SafeERC20 for IERC20;// @note NO CHANGE
    
    // Info of each user.
    struct UserInfo { // @note NO CHANGE
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
    }// @note NO CHANGE

    // Info of each pool.
    // @fixme decrease pool to 2 and not have have deposit fee anymore.    
    struct PoolInfo {
        IERC20 lpToken;           // Address of LP token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. luckys to distribute per block.
        uint256 lastRewardBlock;  // Last block number that luckys distribution occurs.
        uint256 accLuckyPerShare;   // Accumulated luckys per share, times 1e15. See below.
        uint256 harvestTimestamp;  // Harvest interval in unixtimestamp
        uint256 farmStartDate; //the timestamp of farm opening for users to deposit.
    }

    // The lucky TOKEN!
    LuckyToken public lucky;// @note NO CHANGE
    // The SYRUP TOKEN!
    SyrupBar public syrup;// @note NO CHANGE
    // Dev address.
    address public devAddress ;// @note NO CHANGE
    
    //declare the luckyBusd instance here
    IERC20 public luckyBusd ;
    
    // lucky tokens created per block.
    uint256 public luckyPerBlock;// @note NO CHANGE
    // Bonus muliplier for early lucky makers.
    uint256 public constant BONUS_MULTIPLIER = 1;// @note NO CHANGE
    // The migrator contract. It has a lot of power. Can only be set through governance (owner).
    IMigratorChef public migrator;// @note NO CHANGE

    // Info of each pool.
    PoolInfo[] public poolInfo;// @note NO CHANGE
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;// @note NO CHANGE
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;// @note NO CHANGE
    // The block number when lucky mining starts.
    uint256 public startBlock;// @note NO CHANGE
    // Total locked up rewards
    uint256 public totalLockedUpRewards;// @note NO CHANGE
    uint256 private accumulatedRewardForDev;// @note NO CHANGE
    uint256 private constant capRewardForDev = 9 * 10**6 * 10**18;// @note NO CHANGE
    uint256 private devMintingRatio;// @note NO CHANGE
    // @note NO CHANGE
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event LuckyPerBlockUpdated(address indexed caller, uint256 previousAmount, uint256 newAmount);
    event RewardLockedUp(address indexed user, uint256 indexed pid, uint256 amountLockedUp);
    event RewardPaid(address indexed user,uint256 indexed totalRewards);
    event PoolAdded(IERC20 lpToken,uint256 allocPoint,uint256 harvestTimestamp, uint256 farmStartTimestamp);
    event PoolSet(uint256 pid,uint256 allocPoint,uint256 harvestTimestampInUnix, uint256 farmStartTimestampInUnix);
    // note NO CHANGE



    constructor(
        LuckyToken _lucky,
        SyrupBar _syrup,
        IERC20 _luckyBusd,
        address owner_,
        address _devAddress,
        uint256 _startBlock,
        uint256 _luckyPerBlock,
        uint256 _harvestIntervalInMinutes,
        uint256 _farmStartIntervalInMinutes
    ) {
        lucky = _lucky;
        syrup = _syrup;
        luckyBusd = _luckyBusd;
        startBlock = _startBlock;
        luckyPerBlock = _luckyPerBlock;
        devAddress = _devAddress;
        devMintingRatio = 125; //12.5%
        transferOwnership(owner_);
        //add the pools 
        add(8000,lucky,_harvestIntervalInMinutes,_farmStartIntervalInMinutes,true);
        add(40000,luckyBusd,_harvestIntervalInMinutes,_farmStartIntervalInMinutes,true);
    }

    // @note NO CHANGE
    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }// @note NO CHANGE
    
    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    //note that 1x equals 1000 alloc point at the beginning.
    // FIXME decrease pool to 2 and not have have deposit fee anymore.    
    function add(uint256 _allocPoint, IERC20 _lpToken, uint256 _harvestIntervalInMinutes,uint256 _farmStartIntervalInMinutes, bool _withUpdate) public onlyOwner {
        uint256 _harvestTimestampInUnix = block.timestamp + (_harvestIntervalInMinutes *60); //*60 to convert from minutes to second.
        uint256 _farmStartTimestampInUnix = block.timestamp + (_farmStartIntervalInMinutes *60);
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
            harvestTimestamp: _harvestTimestampInUnix,
            farmStartDate : _farmStartTimestampInUnix
        }));
        emit PoolAdded(_lpToken,_allocPoint,_harvestTimestampInUnix,_farmStartTimestampInUnix);
    }// FIXME decrease pool to 2 and not have have deposit fee anymore.    


    // Update the given pool's lucky allocation point and deposit fee. Can only be called by the owner.
    // FIXME decrease pool to 2 and not have have deposit fee anymore.
    function set(uint256 _pid, uint256 _allocPoint, uint256 _harvestIntervalInMinutes,uint256 _farmStartIntervalInMinutes, bool _withUpdate) public onlyOwner {
        uint256 _harvestTimestampInUnix = block.timestamp + (_harvestIntervalInMinutes *60); //*60 to convert from minutes to second.
        uint256 _farmStartTimestampInUnix = block.timestamp + (_farmStartIntervalInMinutes *60);
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
        poolInfo[_pid].harvestTimestamp = _harvestTimestampInUnix;
        poolInfo[_pid].farmStartDate = _farmStartTimestampInUnix;
        emit PoolSet(_pid,_allocPoint,_harvestTimestampInUnix,_farmStartTimestampInUnix);
    }// FIXME decrease pool to 2 and not have have deposit fee anymore.
    
    // Return reward multiplier over the given _from to _to block.
    // @note NO CHANGE
    function getMultiplier(uint256 _from, uint256 _to) public pure returns (uint256) {
        return _to.sub(_from).mul(BONUS_MULTIPLIER);
    }// @note NO CHANGE

    // View function to see pending luckys on frontend.
    // @note NO CHANGE
    function pendingLucky(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accLuckyPerShare = pool.accLuckyPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 luckyReward = multiplier.mul(luckyPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accLuckyPerShare = accLuckyPerShare.add(luckyReward.mul(1e15).div(lpSupply));
        }
        uint256 pending = user.amount.mul(accLuckyPerShare).div(1e15).sub(user.rewardDebt);
        return pending.add(user.rewardLockedUp);
    }// @note NO CHANGE

    // View function to see if user can harvest luckys.
    // @note NO CHANGE
    function canHarvest(uint256 _pid) public view returns (bool) {
        //UserInfo storage user = userInfo[_pid][_user];
        PoolInfo storage pool = poolInfo[_pid];
        return block.timestamp >= pool.harvestTimestamp;
    }// @note NO CHANGE

    // Update reward variables for all pools. Be careful of gas spending!
    // @note NO CHANGE
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }// @note NO CHANGE
    // Set the migrator contract. Can only be called by the owner.
    // @note NO CHANGE
    function setMigrator(IMigratorChef _migrator) public onlyOwner {
        migrator = _migrator;
    }// @note NO CHANGE

    // Migrate lp token to another lp contract. Can be called by anyone. We trust that migrator contract is good.
    // @note NO CHANGE
    function migrate(uint256 _pid) public {
        require(address(migrator) != address(0), "migrate: no migrator");
        PoolInfo storage pool = poolInfo[_pid];
        IERC20 lpToken = pool.lpToken;
        uint256 bal = lpToken.balanceOf(address(this));
        lpToken.safeApprove(address(migrator), bal);
        IERC20 newLpToken = migrator.migrate(lpToken);
        require(bal == newLpToken.balanceOf(address(this)), "migrate: bad");
        pool.lpToken = newLpToken;
    }// @note NO CHANGE
    
    // Update reward variables of the given pool to be up-to-date.
    // @note NO CHANGE
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
        // check at final to mint exact lucky to complete the round 9 million and 100 millions totalsupply 
        uint256 luckyRewardForDev = luckyReward.mul(devMintingRatio).div(1000);
        //logic to prevent the minting exceeds the capped totalsupply
        //1st case, reward for dev will exceed Lucky's totalSupply so we limit the minting amount to syrup.
        if (luckyRewardForDev.add(lucky.totalSupply()) > lucky.cap() ) {
            uint256 remainingReward = lucky.cap().sub(lucky.totalSupply());
            //in case that remainingReward > capped reward for dev.
            if (remainingReward.add(accumulatedRewardForDev) > capRewardForDev) {
                uint256 lastRemainingRewardForDev = capRewardForDev.sub(accumulatedRewardForDev);
                lucky.mint(devAddress,lastRemainingRewardForDev);
                accumulatedRewardForDev = accumulatedRewardForDev.add(lastRemainingRewardForDev);
                //the rest is minted to users.
                lucky.mint(address(syrup),lucky.cap().sub(lucky.totalSupply()));
            }
            //normal case that dev's caped reward has not been reached yet, but the totalSupply of Lucky is reached.
            else {
                lucky.mint(devAddress, remainingReward);
                //track the token that is minted to dev.
                accumulatedRewardForDev = accumulatedRewardForDev.add(remainingReward);
            }
            
        }
        //supply cap was not reached and capRewardForDevev still has room to mint for.
        else {
            //capRewardForDev is reached.
            if (luckyRewardForDev.add(accumulatedRewardForDev) > capRewardForDev) {
                uint256 lastRemainingRewardForDev = capRewardForDev.sub(accumulatedRewardForDev);
                lucky.mint(devAddress,lastRemainingRewardForDev);
                //track the token that is minted to dev.
                accumulatedRewardForDev = accumulatedRewardForDev.add(lastRemainingRewardForDev);
                
                //mint the left portion of dev to the pools.
                lucky.mint(address(syrup),luckyRewardForDev.sub(lastRemainingRewardForDev));
                
                if (luckyReward.add(lucky.totalSupply()) > lucky.cap() ){
                    lucky.mint(address(syrup),lucky.cap().sub(lucky.totalSupply()));
                }
                else {
                    lucky.mint(address(syrup),luckyReward);
                }
            }
            
            else { 
                
                lucky.mint(devAddress,luckyRewardForDev);
                accumulatedRewardForDev = accumulatedRewardForDev.add(luckyRewardForDev);
                
                if (luckyReward.add(lucky.totalSupply()) > lucky.cap() ){
                    lucky.mint(address(syrup),lucky.cap().sub(lucky.totalSupply()));
                }
                else{
                    lucky.mint(address(syrup),luckyReward);
                }
                
            }
        }
        pool.accLuckyPerShare = pool.accLuckyPerShare.add(luckyReward.mul(1e15).div(lpSupply));
        pool.lastRewardBlock = block.number;
    }// @note NO CHANGE

    // Deposit LP tokens to MasterChef for lucky allocation.
    // @note NO CHANGE
    function deposit(uint256 _pid, uint256 _amount) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(pool.farmStartDate <= block.timestamp,"unable to deposit before the farm starts.");
        //can not harvest(deposit 0) before the harvestTimestamp.
        if (!canHarvest(_pid) && _amount==0){
            require(pool.harvestTimestamp <= block.timestamp,"can not harvest before the harvestTimestamp" ); //newly added
        }
        updatePool(_pid);
        payOrLockupPendingLucky(_pid);
        if (_amount > 0) {
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(pool.accLuckyPerShare).div(1e15);
        emit Deposit(msg.sender, _pid, _amount);
    }// @note NO CHANGE

    // Withdraw LP tokens from MasterChef.
    // @note NO CHANGE
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
        user.rewardDebt = user.amount.mul(pool.accLuckyPerShare).div(1e15);
        emit Withdraw(msg.sender, _pid, _amount);
    }// @note NO CHANGE

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    // @note NO CHANGE
    function emergencyWithdraw(uint256 _pid) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        user.rewardLockedUp = 0;
        pool.lpToken.safeTransfer(address(msg.sender), amount);
        emit EmergencyWithdraw(msg.sender, _pid, amount);
    }// @note NO CHANGE

    // Pay or lockup pending luckys.
    // @note NO CHANGE
    function payOrLockupPendingLucky(uint256 _pid) internal {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        uint256 pending = user.amount.mul(pool.accLuckyPerShare).div(1e15).sub(user.rewardDebt);
        if (canHarvest(_pid)) {
            if (pending > 0 || user.rewardLockedUp > 0) {
                uint256 totalRewards = pending.add(user.rewardLockedUp);

                // reset lockup
                totalLockedUpRewards = totalLockedUpRewards.sub(user.rewardLockedUp);
                user.rewardLockedUp = 0;

                // send rewards
                safeLuckyTransfer(msg.sender, totalRewards);
                emit RewardPaid(msg.sender,totalRewards);
            }
        } else if (pending > 0) {
            user.rewardLockedUp = user.rewardLockedUp.add(pending);
            totalLockedUpRewards = totalLockedUpRewards.add(pending);
            emit RewardLockedUp(msg.sender, _pid, pending);
        }
    }// @note NO CHANGE

    // Safe lucky transfer function, just in case if rounding error causes pool to not have enough luckys.
    // @note NO CHANGE
    function safeLuckyTransfer(address _to, uint256 _amount) internal {
        syrup.safeLuckyTransfer(_to, _amount);
    }// @note NO CHANGE

    // Update dev address by the previous dev.
    // @note NO CHANGE
    function setDevAddress(address _devAddress) public onlyOwner{
        require(_devAddress != address(0), "setDevAddress: ZERO");
        devAddress = _devAddress;
    }// @note NO CHANGE

    // Pancake has to add hidden dummy pools in order to alter the emission, here we make it simple and transparent to all.
    // @note NO CHANGE
    function updateLuckyPerBlock(uint256 _luckyPerBlock) public onlyOwner {
        massUpdatePools();
        emit LuckyPerBlockUpdated(msg.sender, luckyPerBlock, _luckyPerBlock);
        //this is the new one
        uint256 prevLuckyPerBlock = luckyPerBlock;
        if (prevLuckyPerBlock !=_luckyPerBlock){
            luckyPerBlock = _luckyPerBlock;
        }
    }// @note NO CHANGE

    // @note NO CHANGE
    function getBlockNumber () public view returns(uint256){
        return block.number;
    }// @note NO CHANGE
    
    // @note NO CHANGE
    function getBlockTimestamp () public view returns(uint256){
        return block.timestamp;
    }// @note NO CHANGE
    
    //return countdown time in second of the pool id when user can harvest their reward.
    // @note NO CHANGE
    function harvestCountdown(uint8 _poolID) public view returns(uint256){
        if (poolInfo[_poolID].harvestTimestamp >=block.timestamp ){
            return poolInfo[_poolID].harvestTimestamp - block.timestamp;
        }
        else{  
            return 0;
        }
    }// @note NO CHANGE

    //return countdown time in second of the pool id when user can deposit into that pool.
    // @note NO CHANGE
    function farmStartCountdown(uint8 _poolID) public view returns(uint256){
        if (poolInfo[_poolID].farmStartDate >= block.timestamp ){
            return poolInfo[_poolID].farmStartDate - block.timestamp;
        }
        else{
            return 0;
        }
    }// @note NO CHANGE
}
