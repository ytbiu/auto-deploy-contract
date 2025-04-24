# XAASwap 合约接口文档

## 概述
`XAASwap` 合约用于在固定的质押期内存入 DBC（原生代币，如 ETH）以换取 XAA 代币。用户可以在质押期内存入 DBC，并在分发期开始后按存入DBC比例领取奖励（XAA 代币）。合约还允许所有者在质押期结束后提取未领取的 DBC。

## 合约接口

### 事件

#### `Deposit`
当用户将 DBC 存入合约时触发。

- **参数**：
    - `user (address)`：存款用户的地址。
    - `amount (uint256)`：存入的 DBC 数量。

#### `RewardClaimed`
当用户成功领取其 XAA 奖励时触发。

- **参数**：
    - `user (address)`：领取奖励的用户地址。
    - `amount (uint256)`：领取的 XAA 奖励数量。

#### `DBCClaimed`
当所有者提取未领取的 DBC 时触发。

- **参数**：
    - `owner (address)`：提取 DBC 的所有者地址。
    - `amount (uint256)`：提取的 DBC 数量。

### 状态变量

#### `xaaToken`
XAA ERC20 代币的地址。

- **类型**：`address`

#### `startTime`
质押期开始的时间戳。

- **类型**：`uint256`

#### `endTime`
质押期结束的时间戳。

- **类型**：`uint256`

#### `totalDepositedDBC`
所有用户存入的 DBC 总量。

- **类型**：`uint256`

#### `userDeposits`
记录用户地址与其存入的 DBC 数量的映射。

- **类型**：`mapping(address => uint256)`

#### `hasClaimed`
记录用户地址与其是否已领取奖励的映射。

- **类型**：`mapping(address => bool)`

### 函数

#### `receive()` 可以直接像合约 `address` 发送 DBC。
允许用户在质押期内将 DBC 存入合约。

- **参数**：
    - `value (uint256)`：随交易发送的 DBC 数量。

- **要求**：
    - 当前时间戳必须在质押期内。
    - 存入的数量必须大于零。

- **效果**：
    - 更新用户的存款余额。
    - 增加总存入的 DBC 数量。
    - 触发 `Deposit` 事件。

#### `claimRewards`
允许用户在分发期开始后领取其 XAA 奖励。

- **要求**：
    - 分发期必须已开始。
    - 用户必须已存入 DBC。
    - 用户尚未领取过奖励。

- **效果**：
    - 根据用户的存款比例转移相应的 XAA 代币。
    - 标记用户已领取奖励。
    - 触发 `RewardClaimed` 事件。

#### `claimDBC`
允许所有者在质押期结束后提取未领取的 DBC。

- **要求**：
    - 质押期必须已结束。
    - 仅所有者可以调用此函数。
    - 合约中必须有未领取的 DBC 余额。

- **效果**：
    - 将所有未领取的 DBC 转移给所有者。
    - 触发 `DBCClaimed` 事件。

### 修饰符

#### `onlyOwner`
限制只有合约所有者可以访问。

#### `onlyDuringDepositPeriod`
确保函数在质押期内被调用。

#### `onlyAfterDistributionStarts`
确保函数在分发期开始后被调用。

## 关键常量

- `TOTAL_XAA_REWARD (uint256)`
    - 分发的 XAA 奖励总量。
    - 默认值：`20_000_000_000 * 1e18`

- `DEPOSIT_PERIOD (uint256)`
    - 质押期的持续时间。
    - 默认值：`14 days`


