const { expectRevert, time } = require('@openzeppelin/test-helpers')
const LuckyToken = artifacts.require('LuckyToken')
const SyrupBar = artifacts.require('SyrupBar')
const MasterChef = artifacts.require('MasterChef')
const MockERC20 = artifacts.require('libs/MockERC20')

contract('MasterChef', ([alice, bob, carol, ohm, lemon, prem, dev, minter, owner, warchest, ecosystem, fee]) => {
  beforeEach(async () => {
    this.lucky = await LuckyToken.new(owner, warchest, ecosystem, { from: minter })
    this.syrup = await SyrupBar.new(this.lucky.address, owner, { from: minter })
    this.luckyBUSD = await MockERC20.new('luckyBUSD', 'luckyBUSD', minter, '1000000', { from: minter })
    //we set luckyperblock = 100 lucky = 100000000000000000000 wei
    this.chef = await MasterChef.new(
      this.lucky.address,
      this.syrup.address,
      this.luckyBUSD.address,
      owner,
      dev,
      '0',
      '100000000000000000000',
      3,
      1,
      { from: owner }
    )
    await this.lucky.transferOwnership(this.chef.address, { from: owner })
    await this.syrup.transferOwnership(this.chef.address, { from: owner })

    await this.luckyBUSD.transfer(alice, '200', { from: minter })
    await this.lucky.transfer(carol, '200', { from: warchest })
  })
  it('real case have all the pools deposit and withdraw', async () => {
    //approve all the LP tokens before depositing to the masterchef.
    //
    await this.lucky.approve(this.chef.address, '100000', { from: carol })
    await this.luckyBUSD.approve(this.chef.address, '10000', { from: alice })

    await time.increase('61')
    await time.advanceBlockTo('29')

    await this.chef.deposit(0, '100', { from: alice })
    assert.equal((await this.chef.getBlockNumber()).toString(), '30')
    await this.chef.deposit(1, '100', { from: carol })
    assert.equal((await this.chef.getBlockNumber()).toString(), '31')

    await this.chef.deposit(0, '100', { from: alice })
    await this.chef.deposit(1, '100', { from: carol })

    assert.equal((await this.lucky.balanceOf(carol)).toString(), '0')
    assert.equal((await this.luckyBUSD.balanceOf(alice)).toString(), '0')
    assert.equal((await this.lucky.balanceOf(this.chef.address)).toString(), '200')

    //scroll the time to the 3 6mins
    await time.increase('200')

    await time.advanceBlockTo('199')

    await this.chef.withdraw(0, '200', { from: alice }) //200
    await this.chef.withdraw(1, '200', { from: carol }) //201
    assert.equal((await this.lucky.balanceOf(alice)).toString(), '14166666666666666666666')
    assert.equal((await this.lucky.balanceOf(carol)).toString(), '2833333333333333333533')
    assert.equal((await this.lucky.balanceOf(dev)).toString(), '2354499999999999999999')
  })

  it('can not deposit before farm starts', async () => {
    //approve all the LP tokens before depositing to the masterchef.
    //Alice
    await this.lucky.approve(this.chef.address, '1000000000', { from: carol })
    await this.luckyBUSD.approve(this.chef.address, '1000000000', { from: alice })

    //deposit before the farm starts
    await expectRevert(this.chef.deposit(0, '50', { from: alice }), 'unable to deposit before the farm starts.')
    await expectRevert(this.chef.deposit(1, '50', { from: carol }), 'unable to deposit before the farm starts.')
  })

  it('can not harvest before the defined harvest timestamp', async () => {
    await this.chef.set('0', '30000', 3, 1, true, { from: owner })
    //approve all the LP tokens before depositing to the masterchef.
    //Alice
    await this.luckyBUSD.approve(this.chef.address, '1000000000', { from: alice })

    await time.increase('60') //increase the time to the farm opening time.
    assert.equal((await this.luckyBUSD.balanceOf(alice)).toString(), '200')
    await this.chef.deposit(0, '50', { from: alice })

    assert.equal((await this.chef.canHarvest(0)).toString(), 'false')
    await expectRevert(this.chef.deposit(0, '0', { from: alice }), 'can not harvest before the harvestTimestamp')
    await this.chef.deposit(0, '50', { from: alice })
    assert.equal((await this.lucky.balanceOf(alice)).toString(), '0')
  })

  it('should allow only owner to update dev', async () => {
    //set the dev address
    assert.equal((await this.chef.devAddress()).valueOf(), dev)
    await expectRevert(this.chef.setDevAddress(bob, { from: bob }), 'Ownable: caller is not the owner')
    await this.chef.setDevAddress(bob, { from: owner })
    assert.equal((await this.chef.devAddress()).valueOf(), bob)
    await this.chef.setDevAddress(dev, { from: owner })
    assert.equal((await this.chef.devAddress()).valueOf(), dev)
  })

  it("Masterchef stops to mint when Lucky's cap is reached", async () => {
    //approve all the LP tokens before depositing to the masterchef.
    //Alice
    await this.luckyBUSD.approve(this.chef.address, '100', { from: alice })

    //carol
    await this.lucky.approve(this.chef.address, '100', { from: carol })

    //owner change the mintperblock to reach the maximum capacity of the LuckyToken
    await this.chef.updateLuckyPerBlock('1000000000000000000000000', { from: owner })

    await time.increase('301') //increase the time to the farm opening time.
    //deposit to the luckyBusd farm
    //alice
    await time.advanceBlockTo('2000')
    await this.chef.deposit(1, '50', { from: carol })
    await this.chef.deposit(1, '50', { from: carol })
    assert.equal((await this.lucky.balanceOf(this.chef.address)).toString(), '100')
    await this.chef.deposit(0, '50', { from: alice })
    await this.chef.deposit(0, '50', { from: alice })

    await time.advanceBlockTo('2100') //increase block to the first hour in blocks unit
    //withdraw from the farm and also collect the reward.
    await this.chef.withdraw(0, '100', { from: alice }) //withdraw to also get the reward along with the withdrawal amount.
    await this.chef.withdraw(1, '100', { from: carol })

    //check lucky tokens balance
    assert.equal((await this.lucky.balanceOf(dev)).toString(), '9000000000000000000000000')
    assert.equal((await this.lucky.balanceOf(fee)).toString(), '0')
    assert.equal((await this.lucky.totalSupply()).toString(), '100000000000000000000000000')
  })
})
