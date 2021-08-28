# Lucky-farm

Smart contract for Lucky farming.

## deployed contracts on Binance smart chain Testnet

  ### Masterchef 
  
  contract that manages all the farming pool and rewards.
    
    address >> 0x01cA7763B9dF1a0bC5c0504b53eb61e8b694F70A
  
    solidity contract >> Masterchef.sol
    
    note : you can pull the harvest timpstamp by getting harvestTimpstamp(poolID) function in the Masterchef contract address
  
  ### LuckyToken
  
  Lucky governance token to be minted by the Masterchef.
    
    address >> 0x2977997472d4fa0570ECfA882A16048c0473953f
  
    solidity contract >> LuckyToken.sol
  
  ### MockBNB (ERC20) 
    
  to be used as LP tokens for pool ID 1,2,3,4 and 5. Note that you can mint MockBNB by yourself in order to add the LP in the pool.
    
    address >> 0x5bfE5A9D987613Bd78a8C2F4EEcEF3baC02B045A 
  
    solidity contract >> MockBNB.sol
  
  
  
