const { expectRevert, time } = require('@openzeppelin/test-helpers');
const ethers = require('ethers');
const LuckyToken = artifacts.require('LuckyToken');
const MasterChef = artifacts.require('MasterChef');
const MockERC20 = artifacts.require('libs/MockERC20');
const Timelock = artifacts.require('Timelock');
const SyrupBar = artifacts.require('SyrupBar');

function encodeParameters(types, values) {
    const abi = new ethers.utils.AbiCoder();
    return abi.encode(types, values);
}

contract('Timelock', ([alice, carol, dev, minter, owner, warchest, ecosystem, fee]) => {
    beforeEach(async () => {
        this.lucky = await LuckyToken.new(owner, warchest, ecosystem, { from: minter })
        this.timelock = await Timelock.new(owner, '28800', { from: minter }); //8hours
    });

    it('should not allow non-owner to do operation', async () => {
        await this.lucky.transferOwnership(this.timelock.address, { from: owner });
        await expectRevert(
            this.lucky.transferOwnership(carol, { from: alice }),
            'Ownable: caller is not the owner',
        );
        await expectRevert(
            this.lucky.transferOwnership(carol, { from: dev }),
            'Ownable: caller is not the owner',
        );
        await expectRevert(
            this.timelock.queueTransaction(
                this.lucky.address, '0', 'transferOwnership(address)',
                encodeParameters(['address'], [carol]),
                (await time.latest()).add(time.duration.hours(6)),
                { from: alice },
            ),
            'Timelock::queueTransaction: Call must come from admin.',
        );
    });

    it('should do the timelock thing', async () => {
        await this.lucky.transferOwnership(this.timelock.address, { from: owner });
        const eta = (await time.latest()).add(time.duration.hours(9));
        await this.timelock.queueTransaction(
            this.lucky.address, '0', 'transferOwnership(address)',
            encodeParameters(['address'], [carol]), eta, { from: owner },
        );
        await time.increase(time.duration.hours(1));
        await expectRevert(
            this.timelock.executeTransaction(
                this.lucky.address, '0', 'transferOwnership(address)',
                encodeParameters(['address'], [carol]), eta, { from: owner },
            ),
            "Timelock::executeTransaction: Transaction hasn't surpassed time lock.",
        );
        await time.increase(time.duration.hours(8));
        await this.timelock.executeTransaction(
            this.lucky.address, '0', 'transferOwnership(address)',
            encodeParameters(['address'], [carol]), eta, { from: owner },
        );
        assert.equal((await this.lucky.owner()).valueOf(), carol);
    });

    it('should also work with MasterChef', async () => {
        this.lp1 = await MockERC20.new('LPToken', 'LP', minter, '1000000', { from: minter })
        this.syrup = await SyrupBar.new(this.lucky.address, owner,{ from: minter });
        this.luckyBUSD = await MockERC20.new('luckyBUSD', 'luckyBUSD', minter, '1000000', { from: minter })
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
        await this.lucky.transferOwnership(this.chef.address, { from: owner });
        await this.syrup.transferOwnership(this.chef.address, { from: owner });
        await this.chef.add('100', this.lp1.address, 0, 0, true, { from: owner });
        await this.chef.transferOwnership(this.timelock.address, { from: owner });
        await expectRevert(
            this.chef.add('100', this.lp1.address, 0, 0, true, { from: owner }),
            "revert Ownable: caller is not the owner",
        );

        const eta = (await time.latest()).add(time.duration.hours(9));
        await this.timelock.queueTransaction(
            this.chef.address, '0', 'transferOwnership(address)',
            encodeParameters(['address'], [minter]), eta, { from: owner },
        );
        await time.increase(time.duration.hours(9));
        await this.timelock.executeTransaction(
            this.chef.address, '0', 'transferOwnership(address)',
            encodeParameters(['address'], [minter]), eta, { from: owner },
        );
        await expectRevert(
            this.chef.add('100', this.lp1.address, 0, 0, true, { from: owner }),
            "revert Ownable: caller is not the owner",
        );
        await this.chef.add('100', this.lp1.address, 0, 0, true, { from: minter })
    });
});