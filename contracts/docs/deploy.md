## Deploy XAA IAO
To deploy XAA IAO, follow the steps below:

1. Clone the repository

2. `cd` to the repository directory

3. Write environment variables in a `.env` file in the root directory of the repository. The `.env` file should contain the following variables:
   - `PRIVATE_KEY`: The private key of the account that will be used to deploy the contracts.
   - `XAAIAO_NFT_HOLDER_CONTRACT` : The address of the NFT holder contract. (0xc488736c09ab088e5203b48d973dca30581d6118)
   - `XAAIAO_OWNER`: The address of the owner of the XAA IAO contract.
   - `XAAIAO_TOKEN_IN_CONTRACT`: The address of the token to deposit to the XAA IAO contract address .
   - `XAAIAO_REWARD_TOKEN_CONTRACT`: The address of the reward token contract address.
   - `XAAIAO_START_TIMESTAMP`: The timestamp when the XAA IAO contract will start.
   - ``