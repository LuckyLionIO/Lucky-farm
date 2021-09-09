const { expectRevert, time } = require('@openzeppelin/test-helpers');
const LuckyToken = artifacts.require('LuckyToken');
const SyrupBar = artifacts.require('SyrupBar');
const MasterChef = artifacts.require('MasterChef');
const MockERC20 = artifacts.require('libs/MockERC20');

contract('MasterChef', ([alice, bob, carol,ohm,lemon,prem, dev, minter,owner,warchest,ecosystem,fee]) => {
    beforeEach(async () => {
        this.lucky = await LuckyToken.new(owner,warchest,ecosystem,{ from: minter });
        this.syrup = await SyrupBar.new(this.lucky.address, owner,{ from: minter });
        this.luckyBNB = await MockERC20.new('luckyBNB', 'luckyBNB', minter,'1000000', { from: minter });
        this.luckyBUSD = await MockERC20.new('luckyBUSD', 'luckyBUSD',minter, '1000000', { from: minter });
        this.WBnbPool = await MockERC20.new('WBnbPool', 'WBnbPool',minter, '1000000', { from: minter });
        this.BnbBusdPool = await MockERC20.new('BnbBusdPool', 'BnbBusdPool',minter, '1000000', { from: minter });
        this.UsdtBusdPool = await MockERC20.new('UsdtBusdPool', 'UsdtBusdPool',minter, '1000000', { from: minter });
        //we set luckyperblock = 100 lucky = 100000000000000000000 wei
        this.chef = await MasterChef.new(this.lucky.address,this.syrup.address,owner,dev,fee, '0', '100000000000000000000',{ from: owner });
        this.chef.add(6500,this.lucky.address,0, 3,1, true, { from: owner });
        this.chef.add(30000,this.luckyBUSD.address,0, 3,1, true, { from: owner });
        this.chef.add(40000,this.luckyBNB.address,0, 3,1, true, { from: owner });
        this.chef.add(1300,this.WBnbPool.address,200, 3,1, true, { from: owner });
        this.chef.add(8000,this.BnbBusdPool.address,200, 3,1, true, { from: owner });
        this.chef.add(2000,this.UsdtBusdPool.address,200, 3,1, true, { from: owner });
        await this.lucky.transferOwnership(this.chef.address, { from: owner });
        await this.syrup.transferOwnership(this.chef.address, { from: owner });
        

        await this.lucky.transfer(carol, '200', { from: warchest });
        await this.luckyBUSD.transfer(alice, '200', { from: minter });
        await this.luckyBNB.transfer(bob, '200', { from: minter });
        await this.WBnbPool.transfer(prem, '200', { from: minter });
        await this.BnbBusdPool.transfer(ohm, '200', { from: minter });
        await this.UsdtBusdPool.transfer(lemon, '200', { from: minter }); 

    });
    it('real case have all the pools deposit and withdraw', async () => {

            //approve all the LP tokens before depositing to the masterchef.
            //
            await this.lucky.approve(this.chef.address, '100000', { from: carol });
            await this.luckyBUSD.approve(this.chef.address, '10000', { from: alice });
            await this.luckyBNB.approve(this.chef.address, '100000', { from: bob });
            await this.WBnbPool.approve(this.chef.address, '100000', { from: prem });
            await this.BnbBusdPool.approve(this.chef.address, '100000', { from: ohm });
            await this.UsdtBusdPool.approve(this.chef.address, '100000', { from: lemon });
            
            await time.increase("61")
            await time.advanceBlockTo("29")

            await this.chef.deposit(0,"100",{from:carol});
            assert.equal((await this.chef.getBlockNumber()).toString(), '30');
            await this.chef.deposit(1,"100",{from:alice});
            assert.equal((await this.chef.getBlockNumber()).toString(), '31');
            await this.chef.deposit(2,"100",{from:bob});
            assert.equal((await this.chef.getBlockNumber()).toString(), '32');
            await this.chef.deposit(3,"100",{from:prem});
            assert.equal((await this.chef.getBlockNumber()).toString(), '33');
            await this.chef.deposit(4,"100",{from:ohm});
            assert.equal((await this.chef.getBlockNumber()).toString(), '34');
            await this.chef.deposit(5,"100",{from:lemon});
            assert.equal((await this.chef.getBlockNumber()).toString(), '35');

            await this.chef.deposit(0,"100",{from:carol});
            await this.chef.deposit(1,"100",{from:alice});
            await this.chef.deposit(2,"100",{from:bob});
            await this.chef.deposit(3,"100",{from:prem});
            await this.chef.deposit(4,"100",{from:ohm});
            await this.chef.deposit(5,"100",{from:lemon});

            
            assert.equal((await this.lucky.balanceOf(carol)).toString(), '0');
            assert.equal((await this.luckyBUSD.balanceOf(alice)).toString(), '0');
            assert.equal((await this.luckyBNB.balanceOf(bob)).toString(), '0');
            assert.equal((await this.WBnbPool.balanceOf(prem)).toString(), '0');
            assert.equal((await this.BnbBusdPool.balanceOf(ohm)).toString(), '0');
            assert.equal((await this.UsdtBusdPool.balanceOf(lemon)).toString(), '0');
            assert.equal((await this.lucky.balanceOf(this.chef.address)).toString(), '200');
            
            //scroll the time to the 3 6mins
            await time.increase("200")

            await time.advanceBlockTo("199")

            await this.chef.withdraw(0,"200",{from:carol});//200
            await this.chef.withdraw(1,"200",{from:alice});//201
            await this.chef.withdraw(2,"200",{from:bob});//202
            await this.chef.withdraw(3,"196",{from:prem});//203
            await this.chef.withdraw(4,"196",{from:ohm});//204
            await this.chef.withdraw(5,"196",{from:lemon});//205
            assert.equal((await this.lucky.balanceOf(carol)).toString(), '1105000000000000000200');
            assert.equal((await this.lucky.balanceOf(alice)).toString(), '5100000000000000000000');
            assert.equal((await this.lucky.balanceOf(bob)).toString(), '6800000000000000000000');
            assert.equal((await this.lucky.balanceOf(prem)).toString(), '220999999999999999999');//should be 221000000000000000000, but the system deduct due to mathematics calculations
            assert.equal((await this.lucky.balanceOf(ohm)).toString(), '1359999999999999999999');
            assert.equal((await this.lucky.balanceOf(lemon)).toString(), '339999999999999999999');

          })

          
    it('can not deposit before farm starts', async () => {
      //approve all the LP tokens before depositing to the masterchef.
      //Alice
      await this.luckyBNB.approve(this.chef.address, '1000000000', { from: alice });
      await this.luckyBUSD.approve(this.chef.address, '1000000000', { from: alice });
      await this.WBnbPool.approve(this.chef.address, '1000000000', { from: alice });
      await this.BnbBusdPool.approve(this.chef.address, '1000000000', { from: alice });
      await this.UsdtBusdPool.approve(this.chef.address, '1000000000', { from: alice });
      await this.luckyBUSD.approve(this.chef.address, '1000000000', { from: alice });
      //Bob
      await this.luckyBNB.approve(this.chef.address, '1000000000', { from: bob });
      await this.luckyBUSD.approve(this.chef.address, '1000000000', { from: bob });
      await this.WBnbPool.approve(this.chef.address, '1000000000', { from: bob });
      await this.BnbBusdPool.approve(this.chef.address, '1000000000', { from: bob });
      await this.UsdtBusdPool.approve(this.chef.address, '1000000000', { from: bob });
      await this.luckyBUSD.approve(this.chef.address, '1000000000', { from: bob });

      //deposit before the farm starts
      await expectRevert(this.chef.deposit(1, '50', { from: alice }), 'unable to deposit before the farm starts.'); 
      await expectRevert(this.chef.deposit(2, '50', { from: alice }), 'unable to deposit before the farm starts.'); 
  })

  it('can not harvest before the defined harvest timestamp', async () => {
    
    await this.chef.set("1","30000","0",3,1,true, { from: owner });
    //approve all the LP tokens before depositing to the masterchef.
    //Alice
    await this.luckyBUSD.approve(this.chef.address, '1000000000', { from: alice });

    await time.increase("60") //increase the time to the farm opening time.
    assert.equal((await this.luckyBUSD.balanceOf(alice)).toString(), '200');
    await this.chef.deposit(1, '50', { from: alice });
    
    assert.equal((await this.chef.canHarvest(1)).toString(),"false");
    await expectRevert(this.chef.deposit(1, '0', { from: alice }), 'can not harvest before the harvestTimestamp');
    await this.chef.deposit(1, '50', { from: alice }); 
    assert.equal((await this.lucky.balanceOf(alice)).toString(), '0');

})


    it('should allow only owner to update dev and fee address', async () => {
        //set the dev address

        assert.equal((await this.chef.devAddress()).valueOf(), dev);
        await expectRevert(this.chef.setDevAddress(bob, { from: bob }), 'Ownable: caller is not the owner');
        await this.chef.setDevAddress(bob, { from: owner });
        assert.equal((await this.chef.devAddress()).valueOf(), bob);
        await this.chef.setDevAddress(dev, { from: owner });
        assert.equal((await this.chef.devAddress()).valueOf(), dev);

        //set the fee address
        assert.equal((await this.chef.feeAddress()).valueOf(), fee);
        await expectRevert(this.chef.setFeeAddress(bob, { from: bob }), 'Ownable: caller is not the owner');
        await this.chef.setFeeAddress(bob, { from: owner });
        assert.equal((await this.chef.feeAddress()).valueOf(), bob);
        await this.chef.setFeeAddress(fee, { from: owner });
        assert.equal((await this.chef.feeAddress()).valueOf(), fee);
    })

    it("Masterchef stops to mint when Lucky's cap is reached", async () => {

      //approve all the LP tokens before depositing to the masterchef.
      //Alice
      await this.lucky.approve(this.chef.address, '100', { from: alice });
      await this.luckyBNB.approve(this.chef.address, '100', { from: alice });
      await this.luckyBUSD.approve(this.chef.address, '100', { from: alice });
      await this.WBnbPool.approve(this.chef.address, '100', { from: alice });
      await this.BnbBusdPool.approve(this.chef.address, '100', { from: alice });
      await this.UsdtBusdPool.approve(this.chef.address, '100', { from: alice });
      //Bob
      await this.lucky.approve(this.chef.address, '100', { from: bob });
      await this.luckyBNB.approve(this.chef.address, '100', { from: bob });
      await this.luckyBUSD.approve(this.chef.address, '100', { from: bob });
      await this.WBnbPool.approve(this.chef.address, '100', { from: bob });
      await this.BnbBusdPool.approve(this.chef.address, '100', { from: bob });
      await this.UsdtBusdPool.approve(this.chef.address, '100', { from: bob });
      //carol
      await this.lucky.approve(this.chef.address, '100', { from: carol });
      //prem
      await this.WBnbPool.approve(this.chef.address, '100000000000', { from: prem });
      //ohm
      await this.BnbBusdPool.approve(this.chef.address, '100000000000', { from: ohm });
      //lemon
      await this.UsdtBusdPool.approve(this.chef.address, '100000000000', { from: lemon });

      //owner change the mintperblock to reach the maximum capacity of the LuckyToken
      await this.chef.updateLuckyPerBlock("1000000000000000000000000",{from:owner});

      await time.increase("301") //increase the time to the farm opening time.

      //deposit to the luckyBusd farm
      //alice
      await time.advanceBlockTo('2000');
      await this.chef.deposit(0, '50', { from: carol });
      await this.chef.deposit(0, '50', { from: carol }); 
      assert.equal((await this.lucky.balanceOf(this.chef.address)).toString(), '100');
      await this.chef.deposit(1, '50', { from: alice });
      await this.chef.deposit(1, '50', { from: alice });
      await this.chef.deposit(2, '50', { from: bob });;//block 501
      await this.chef.deposit(2, '50', { from: bob });;//block 502
      await this.chef.deposit(3, '50', { from: prem });
      await this.chef.deposit(3, '50', { from: prem }); 
      await this.chef.deposit(4, '50', { from: ohm });
      await this.chef.deposit(4, '50', { from: ohm }); 
      await this.chef.deposit(5, '50', { from: lemon });
      await this.chef.deposit(5, '50', { from: lemon }); 

      await time.advanceBlockTo("2100") //increase block to the first hour in blocks unit
      //withdraw from the farm and also collect the reward.
      await this.chef.withdraw(1, '100', { from: alice }); //withdraw to also get the reward along with the withdrawal amount.
      await this.chef.withdraw(2, '100', { from: bob });
      await this.chef.withdraw(3, '98', { from: prem });
      await this.chef.withdraw(4, '98', { from: ohm }); //withdraw to also get the reward along with the withdrawal amount.
      await this.chef.withdraw(5, '98', { from: lemon });
      await this.chef.withdraw(0, '100', { from: carol });
      
      //check LP tokens balance of all users after withdrawing when lucky is fully minted.;
      assert.equal((await this.WBnbPool.balanceOf(fee)).toString(), '2');//2000+4.81m
      assert.equal((await this.BnbBusdPool.balanceOf(fee)).toString(), '2');
      assert.equal((await this.UsdtBusdPool.balanceOf(fee)).toString(), '2');

      //check lucky tokens balance of all users after withdrawing.
      assert.equal((await this.lucky.balanceOf(carol)).toString(), '65000000000000000000200');
      assert.equal((await this.lucky.balanceOf(alice)).toString(), '29400000000000000000000000');
      assert.equal((await this.lucky.balanceOf(bob)).toString(), '35422000000000000000000003');
      assert.equal((await this.lucky.balanceOf(prem)).toString(), '12999999999999999999999');
      assert.equal((await this.lucky.balanceOf(ohm)).toString(), '79999999999999999999999');
      assert.equal((await this.lucky.balanceOf(lemon)).toString(), '19999999999999999999999');
      assert.equal((await this.lucky.balanceOf(dev)).toString(), '9000000000000000000000000');
      assert.equal((await this.lucky.balanceOf(fee)).toString(), '0');
      assert.equal((await this.lucky.totalSupply()).toString(), '100000000000000000000000000');
    })

});
