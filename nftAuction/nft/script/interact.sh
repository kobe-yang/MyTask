#!/bin/bash

# ==========================================
# PriceOracle 交互脚本
# ==========================================
# 使用方法：
# 1. 设置环境变量：
#    export CONTRACT_ADDRESS="0xYourContractAddress"
#    export SEPOLIA_RPC_URL="https://sepolia.infura.io/v3/YOUR_INFURA_ID"
#    export PRIVATE_KEY="0xYourPrivateKey"
# 2. 运行脚本：
#    chmod +x script/interact.sh
#    ./script/interact.sh
# ==========================================

# 配置（可以从环境变量读取）
CONTRACT_ADDRESS="${CONTRACT_ADDRESS:-0xYourContractAddress}"
RPC_URL="${SEPOLIA_RPC_URL:-https://sepolia.infura.io/v3/YOUR_INFURA_ID}"
PRIVATE_KEY="${PRIVATE_KEY:-0xYourPrivateKey}"

# 颜色输出
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}PriceOracle 交互脚本${NC}"
echo -e "${BLUE}==========================================${NC}"
echo -e "合约地址: ${GREEN}$CONTRACT_ADDRESS${NC}"
echo -e "RPC URL: ${GREEN}$RPC_URL${NC}"
echo ""

# 检查合约地址
if [ "$CONTRACT_ADDRESS" = "0xYourContractAddress" ]; then
    echo -e "${YELLOW}警告: 请设置 CONTRACT_ADDRESS 环境变量${NC}"
    echo "export CONTRACT_ADDRESS=\"0xYourContractAddress\""
    exit 1
fi

# 1. 查询 ETH 价格（8 位小数）
echo -e "${BLUE}1. 查询 ETH 价格（8 位小数）:${NC}"
ETH_PRICE_8=$(cast call $CONTRACT_ADDRESS \
  "getEthPrice()(int256)" \
  --rpc-url $RPC_URL 2>/dev/null)

if [ $? -eq 0 ] && [ ! -z "$ETH_PRICE_8" ]; then
    # 转换为可读格式（除以 1e8）
    ETH_PRICE_READABLE=$(echo "scale=2; $ETH_PRICE_8 / 100000000" | bc)
    echo -e "${GREEN}ETH 价格: $ETH_PRICE_READABLE USD${NC}"
    echo "原始值: $ETH_PRICE_8 (8 位小数)"
else
    echo -e "${YELLOW}查询失败${NC}"
fi
echo ""

# 2. 查询 ETH 价格（18 位小数）
echo -e "${BLUE}2. 查询 ETH 价格（18 位小数）:${NC}"
ETH_PRICE_18=$(cast call $CONTRACT_ADDRESS \
  "getEthPriceInUSD()(uint256)" \
  --rpc-url $RPC_URL 2>/dev/null)

if [ $? -eq 0 ] && [ ! -z "$ETH_PRICE_18" ]; then
    # 转换为可读格式（除以 1e18）
    ETH_PRICE_READABLE=$(echo "scale=2; $ETH_PRICE_18 / 1000000000000000000" | bc)
    echo -e "${GREEN}ETH 价格: $ETH_PRICE_READABLE USD${NC}"
    echo "原始值: $ETH_PRICE_18 (18 位小数)"
else
    echo -e "${YELLOW}查询失败${NC}"
fi
echo ""

# 3. 将 1 ETH 转换为美元
echo -e "${BLUE}3. 将 1 ETH 转换为美元:${NC}"
ONE_ETH=1000000000000000000  # 1 ETH in Wei
USD_VALUE=$(cast call $CONTRACT_ADDRESS \
  "ethToUSD(uint256)(uint256)" \
  $ONE_ETH \
  --rpc-url $RPC_URL 2>/dev/null)

if [ $? -eq 0 ] && [ ! -z "$USD_VALUE" ]; then
    USD_VALUE_READABLE=$(echo "scale=2; $USD_VALUE / 1000000000000000000" | bc)
    echo -e "${GREEN}1 ETH = $USD_VALUE_READABLE USD${NC}"
else
    echo -e "${YELLOW}查询失败${NC}"
fi
echo ""

# 4. 获取价格聚合器信息
echo -e "${BLUE}4. 获取价格聚合器信息:${NC}"
FEED_INFO=$(cast call $CONTRACT_ADDRESS \
  "getEthPriceFeedInfo()(uint8,string,uint256)" \
  --rpc-url $RPC_URL 2>/dev/null)

if [ $? -eq 0 ] && [ ! -z "$FEED_INFO" ]; then
    echo -e "${GREEN}价格聚合器信息:${NC}"
    echo "$FEED_INFO"
else
    echo -e "${YELLOW}查询失败${NC}"
fi
echo ""

# 5. 查询合约所有者
echo -e "${BLUE}5. 查询合约所有者:${NC}"
OWNER=$(cast call $CONTRACT_ADDRESS \
  "owner()(address)" \
  --rpc-url $RPC_URL 2>/dev/null)

if [ $? -eq 0 ] && [ ! -z "$OWNER" ]; then
    echo -e "${GREEN}所有者: $OWNER${NC}"
else
    echo -e "${YELLOW}查询失败${NC}"
fi
echo ""

# 6. 查询价格过期阈值
echo -e "${BLUE}6. 查询价格过期阈值:${NC}"
THRESHOLD=$(cast call $CONTRACT_ADDRESS \
  "stalePriceThreshold()(uint256)" \
  --rpc-url $RPC_URL 2>/dev/null)

if [ $? -eq 0 ] && [ ! -z "$THRESHOLD" ]; then
    THRESHOLD_HOURS=$(echo "scale=1; $THRESHOLD / 3600" | bc)
    echo -e "${GREEN}过期阈值: $THRESHOLD 秒 ($THRESHOLD_HOURS 小时)${NC}"
else
    echo -e "${YELLOW}查询失败${NC}"
fi
echo ""

echo -e "${BLUE}==========================================${NC}"
echo -e "${GREEN}交互完成${NC}"
echo -e "${BLUE}==========================================${NC}"

