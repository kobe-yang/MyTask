# four 目录说明：使用 Foundry 部署 BeggingContract 到 Sepolia 测试网

本文档以 `four/begging/src/BeggingContract.sol` 为例，演示如何：

1. 使用 Foundry 初始化一个项目；
2. 本地编译合约；
3. 配置 Sepolia 测试网络和私钥；
4. 使用 Foundry Script 部署到 Sepolia。

> 说明：以下所有命令默认在终端中于 `four/begging` 目录下执行。

---

## 一、准备环境

- **安装 Foundry（如果尚未安装）**

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

- **进入项目目录**

```bash
cd four/begging
```

---

## 二、初始化 Foundry 项目结构（可选）

如果当前目录还没有 `src`、`script` 等结构，可以先让 Foundry 初始化，然后把已有合约移入：

```bash
cd four
forge init begging
```

> 当前仓库中已经存在 `four/begging/src/BeggingContract.sol`，本步骤仅供参考。

---

## 三、项目配置（foundry.toml）

当前 `four/begging/foundry.toml` 主要内容：

- 指定源码目录：`src = "src"`
- 编译输出目录：`out = "out"`
- 依赖目录：`libs = ["lib"]`
- 编译器版本：`solc = "0.8.20"`
- RPC 端点：`sepolia = "${SEPOLIA_RPC_URL}"`
- Etherscan API：`sepolia = { key = "${ETHERSCAN_API_KEY}" }`

你只需要在系统中正确设置环境变量：

```bash
export SEPOLIA_RPC_URL="https://sepolia.infura.io/v3/<YOUR_INFURA_ID>"
export ETHERSCAN_API_KEY="<YOUR_ETHERSCAN_API_KEY>"
```

---

## 四、安装依赖（forge-std）

部署脚本依赖 `forge-std` 提供的 `Script` 和 `console2`，在 `four/begging` 中运行：

```bash
cd four/begging
forge install foundry-rs/forge-std --no-commit
```

安装完成后，会在 `lib/forge-std` 下生成依赖代码。

---

## 五、部署脚本说明

`four/begging/script/DeployBeggingContract.s.sol` 内容概要：

- 继承 `forge-std/Script.sol`；
- 从环境变量 `PRIVATE_KEY` 读取部署者私钥；
- 使用 `vm.startBroadcast` / `vm.stopBroadcast` 在链上广播交易；
- 部署 `BeggingContract` 并打印合约地址。

简要逻辑：

1. 读取 `PRIVATE_KEY`；
2. `startBroadcast` 开始广播；
3. `new BeggingContract()` 部署合约；
4. `stopBroadcast` 结束广播；
5. 使用 `console2.log` 打印部署地址。

---

## 六、配置私钥与 RPC（Sepolia）

1. **获取测试网 ETH**
   - 去任意 Sepolia 水龙头领取测试币。

2. **在本地设置环境变量（推荐使用 .env + direnv 或手动 export）**

```bash
export PRIVATE_KEY="0x你的私钥（不要泄露主网私钥）"
export SEPOLIA_RPC_URL="https://sepolia.infura.io/v3/<YOUR_INFURA_ID>"
export ETHERSCAN_API_KEY="<YOUR_ETHERSCAN_API_KEY>"
```

> 注意：`PRIVATE_KEY` 必须对应有足够 Sepolia ETH 的地址。

---

## 七、编译合约

在 `four/begging` 目录编译：

```bash
cd four/begging
forge build
```

若编译成功，说明 `BeggingContract` 与部署脚本配置正确。

---

## 八、将 BeggingContract 部署到 Sepolia

在 `four/begging` 目录下执行：

```bash
forge script script/DeployBeggingContract.s.sol:DeployBeggingContract \
  --rpc-url sepolia \
  --broadcast \
  --verify \
  -vvvv
```

参数说明：

- `--rpc-url sepolia`：使用 `foundry.toml` 中配置的 `sepolia` RPC；
- `--broadcast`：实际发送交易到区块链；
- `--verify`：尝试在 Etherscan 上自动验证合约源码（需要 `ETHERSCAN_API_KEY` 正确配置）；
- `-vvvv`：输出更详细的日志，便于排查问题。

运行结束后，终端会输出类似：

- 部署交易哈希；
- 部署的 `BeggingContract` 合约地址；
- （如验证成功）Etherscan 验证结果。

你也可以在脚本中使用的 `console2.log` 输出中看到合约地址。

捐赠
```angular2html
cast send 0xb8AE576d3813716AAb18E27437d9d3C4d7D4a868 "donate()" \
  --value 0.1ether \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key 815ca03bd7f17cb3092b71e438bfa07911c61ad3e27e1ef0b74c77097bdd703b
```


---

## 九、在 Sepolia 上验证部署

1. 打开浏览器，访问 Sepolia Etherscan；
2. 输入上一步输出的合约地址；
3. 查看：
   - 代码验证状态（若 `--verify` 成功则显示为已验证）；
   - 合约余额变化；
   - 捐赠交易记录（调用 `donate` 后可以看到）。

至此，你已经通过 Foundry 成功将 `BeggingContract` 部署到 Sepolia 测试网。


