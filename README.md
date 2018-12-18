# populous-smart-contracts
Smart contracts for platform


## Ropsten Test Network Smart Contract Addresses

```
PXT token - 0xD8A7C588f8DC19f49dAFd8ecf08eec58e64d4cC9, precision - 8

USDC token - 0xF930f2C7Bc02F89D05468112520553FFc6D24801, precision - 6

TUSD token - 0x78e7BEE398D66660bDF820DbDB415A33d011cD48, precision - 18

XAU (ERC1155Mintable.sol) token - 0x9b935e3779098bc5e1ffc073caf916f1e92a6145, precision - 0

GBPp token - 0xe92d265dbe35613468a9ec14a321624faf7653dd, precision - 6

AccessManager.sol - 0x0ebbaf0c3794ed23a0871e411a34be3a1679753a   

PopulousToken.sol - 0x0ff72e24af7c09a647865820d4477f98fcb72a2c, precision - 8     

SafeMath.sol - 0x9ed4a5e4374894818345d711808f36bb21d2c23c          
Populous.sol - 0xa26d388bf5bfc0a03558fc66d8276157904f0d04
DataManager.sol -  0x0f8abf5f708f971bd9a994ec3af40988aa0f4873     
Utils.sol - 0xc8d2eff467f8e9bd9d89a416b24b598afbfe8961
```

Platform Admin/Server Address - `0xf8b3d742b245ec366288160488a12e7a2f1d720d`

## Live Network Smart Contract Addresses


PXT token - `0xc14830e53aa344e8c14603a91229a0b925b0b262`, precision - 8

USDC token - `0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48`, precision - 6

TUSD token - `0x8dd5fbce2f6a956c3022ba3663759011dd51e73e`, precision - 18

XAU (ERC1155Mintable.sol) token - `0x73a3b7dffe9af119621f8467d8609771ab4bc33f`, precision - 0


GBPp token- `0xc1e50afcd71a09f81f1b4e4daa1d1a1a4d678d2a`, precision - 6

AccessManager.sol - `0x98ca4bf7e522cd6d2f69cf843dfab327a1e26497`   
PopulousToken.sol - `0xd4fa1460f537bb9085d22c7bccb5dd450ef28e3a`      
SafeMath.sol - `0x140088cafe35f269d739de277dbe40ba28b8edf1`          
Populous.sol - `0x2428e9af9bc3d66e4ee9604da681c6e5493f8454`    
DataManager.sol - `0xcd565ca18f06e2e4d251b55dc49a4fe456c72052`       
Utils.sol - `0xcab23f0118f87d01a6d2fd3d93aeeaca789c8fb7`

Platform Admin/Server Address - `0x63d509f7152769ddf162ed048b83719fe1e31080`




## Deployment

`truffle@v4.0.0-beta.2`

for ppt transfer to `DepositContract.sol` on the livenet, `39-40 thousand GWei` is required for Gas Limit/Costs

`gas:` 8000000
`gasPrice:` 100000000000

command to unlock account in truffle console - e.g., `web3.personal.unlockAccount(web3.eth.coinbase, 'password', '0x5460')` with time in hex `0x5460` = `21,600 seconds`

note: before redeploying `Populous.sol`, delete `Populous.json and DepositContract.json` in the `build/contracts/` directory first and verify Access Manager `AM()` is set after deployment.

if livenet deployment fails, check transaction queue and if queue is high, remove account and replace with a new one with an empty transaction queue.