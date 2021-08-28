import chai, { expect } from 'chai'
import { Contract } from 'ethers'
import { MaxUint256, AddressZero} from 'ethers/constants'
import { bigNumberify, hexlify, keccak256, defaultAbiCoder, toUtf8Bytes } from 'ethers/utils'
import { solidity, MockProvider, deployContract } from 'ethereum-waffle'
import { ecsign } from 'ethereumjs-util'

import { expandTo8Decimals, getApprovalDigest } from './shared/utilities'

import LuckyToken from '../artifacts/contracts/LuckyToken.sol/LuckyToken.json'

chai.use(solidity)

const TOTAL_SUPPLY = expandTo8Decimals(26 * 1000000)
const TEST_AMOUNT = expandTo8Decimals(10)
const FAIRLAUNCH = expandTo8Decimals(1 * 1000000)
const WARCHEST = expandTo8Decimals(5 * 1000000)
const ECOSYSTEM = expandTo8Decimals(20 * 1000000)
const CAP = expandTo8Decimals(100 * 1000000)

describe('LuckyERC20', () => {
  const provider = new MockProvider({
    hardfork: 'istanbul',
    mnemonic: 'horn horn horn horn horn horn horn horn horn horn horn horn',
    gasLimit: 9999999
  })
  const [dev, owner, WarChest, Ecosystem, other] = provider.getWallets()

  let token: Contract
  beforeEach(async () => {
    token = await deployContract(dev, LuckyToken,[owner.address, WarChest.address, Ecosystem.address])
  })

  it('name, symbol, decimals, cap, totalSupply, balanceOf', async () => {
    expect(await token.name()).to.eq('Lucky')
    expect(await token.symbol()).to.eq('LUCKY')
    expect(await token.decimals()).to.eq(8)
    expect(await token.cap()).to.eq(CAP)
    expect(await token.totalSupply()).to.eq(TOTAL_SUPPLY)
    expect(await token.balanceOf(dev.address)).to.eq(0)
    expect(await token.balanceOf(owner.address)).to.eq(FAIRLAUNCH)
    expect(await token.balanceOf(WarChest.address)).to.eq(WARCHEST)
    expect(await token.balanceOf(Ecosystem.address)).to.eq(ECOSYSTEM)
  })

  it('approve', async () => {
    await expect(token.connect(owner).approve(other.address, TEST_AMOUNT))
      .to.emit(token, 'Approval')
      .withArgs(owner.address, other.address, TEST_AMOUNT)
    expect(await token.allowance(owner.address, other.address)).to.eq(TEST_AMOUNT)
  })

  it('transfer:when not pause', async () => {
    await expect(token.connect(owner).transfer(other.address, TEST_AMOUNT))
      .to.emit(token, 'Transfer')
      .withArgs(owner.address, other.address, TEST_AMOUNT)
    expect(await token.balanceOf(owner.address)).to.eq(FAIRLAUNCH.sub(TEST_AMOUNT))
    expect(await token.balanceOf(other.address)).to.eq(TEST_AMOUNT)
  })

  it('transfer:when pause', async () => {
    await expect(token.connect(owner).pause())
      .to.emit(token, 'Paused')
    await expect(token.connect(owner).transfer(other.address, TEST_AMOUNT))
      .to.be.reverted
    expect(await token.balanceOf(owner.address)).to.eq(FAIRLAUNCH)
    expect(await token.balanceOf(other.address)).to.eq(0)
  })

  it('transfer:fail', async () => {
    await expect(token.connect(owner).transfer(other.address, FAIRLAUNCH.add(1))).to.be.reverted // ds-math-sub-underflow
    await expect(token.connect(other).transfer(owner.address, 1)).to.be.reverted // ds-math-sub-underflow
  })

  it('transferFrom', async () => {
    await token.connect(owner).approve(other.address, TEST_AMOUNT)
    await expect(token.connect(other).transferFrom(owner.address, other.address, TEST_AMOUNT))
      .to.emit(token, 'Transfer')
      .withArgs(owner.address, other.address, TEST_AMOUNT)
    expect(await token.allowance(owner.address, other.address)).to.eq(0)
    expect(await token.balanceOf(owner.address)).to.eq(FAIRLAUNCH.sub(TEST_AMOUNT))
    expect(await token.balanceOf(other.address)).to.eq(TEST_AMOUNT)
  })

  it('transferFrom:max', async () => {
    await token.connect(owner).approve(other.address, MaxUint256)
    await expect(token.connect(other).transferFrom(owner.address, other.address, TEST_AMOUNT))
      .to.emit(token, 'Transfer')
      .withArgs(owner.address, other.address, TEST_AMOUNT)
    expect(await token.allowance(owner.address, other.address)).to.eq(MaxUint256.sub(TEST_AMOUNT)) //
    expect(await token.balanceOf(owner.address)).to.eq(FAIRLAUNCH.sub(TEST_AMOUNT))
    expect(await token.balanceOf(other.address)).to.eq(TEST_AMOUNT)
  })

  it('mint:when not pause', async () => {
    await expect(token.connect(owner).mint(owner.address, TEST_AMOUNT))
      .to.emit(token, 'Transfer')
      .withArgs(AddressZero, owner.address, TEST_AMOUNT)
    expect(await token.balanceOf(owner.address)).to.eq(FAIRLAUNCH.add(TEST_AMOUNT))
  })

  it('mint:when pause', async () => {
    await expect(token.connect(owner).pause())
      .to.emit(token, 'Paused')
    await expect(token.connect(owner).mint(owner.address, TEST_AMOUNT))
      .to.be.reverted
    expect(await token.balanceOf(owner.address)).to.eq(FAIRLAUNCH)
  })

  it('mint:over cap', async () => {
    await expect(token.connect(owner).mint(owner.address, CAP))
      .to.be.reverted
    expect(await token.balanceOf(owner.address)).to.eq(FAIRLAUNCH)
  })
})
