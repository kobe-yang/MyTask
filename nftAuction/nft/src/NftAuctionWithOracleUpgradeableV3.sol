// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./NftAuctionWithOracleUpgradeableV2.sol";

/**
 * @title NftAuctionWithOracleUpgradeableV3
 * @notice V3 版本：在 V2 基础上新增按成交金额动态收取手续费的功能
 * @dev 继承 V2，仅新增状态变量和函数，保持原有存储布局不变，适用于 UUPS 升级
 */
contract NftAuctionWithOracleUpgradeableV3 is NftAuctionWithOracleUpgradeableV2 {
    // ============ 手续费配置 ============

    /// @notice 手续费接收地址（为 address(0) 表示不收取手续费）
    address public feeRecipient;

    /// @notice 较小成交额时的手续费（bps，万分比，1% = 100）
    uint96 public lowFeeBps;

    /// @notice 较大成交额时的手续费（bps，万分比，1% = 100）
    uint96 public highFeeBps;

    /// @notice 手续费档位阈值，按拍卖成交额折算的 USD 数量来判断
    uint256 public feeThresholdUSD;

    /// @notice V3 版本号（与 V1 的 VERSION、V2 的 VERSION_V2 区分）
    uint256 public constant VERSION_V3 = 3;

    event FeeParamsUpdated(
        address indexed feeRecipient,
        uint96 lowFeeBps,
        uint96 highFeeBps,
        uint256 feeThresholdUSD
    );

    event FeeCharged(
        address indexed payer,
        address indexed seller,
        uint256 grossAmount,
        uint256 feeAmount,
        uint96 feeBps,
        BidType bidType,
        address bidToken
    );

    // ============ V3 初始化 ============

    /**
     * @notice V3 版本初始化（升级后可调用一次）
     * @dev 使用 reinitializer(2)，与 V1 的 initializer 版本号区分
     */
    function initializeV3(
        address _feeRecipient,
        uint96 _lowFeeBps,
        uint96 _highFeeBps,
        uint256 _feeThresholdUSD
    ) external reinitializer(2) onlyOwner {
        _setFeeParams(_feeRecipient, _lowFeeBps, _highFeeBps, _feeThresholdUSD);
    }

    /**
     * @notice 后续如需调整手续费参数，可由 owner 调用本函数
     */
    function setFeeParams(
        address _feeRecipient,
        uint96 _lowFeeBps,
        uint96 _highFeeBps,
        uint256 _feeThresholdUSD
    ) external onlyOwner {
        _setFeeParams(_feeRecipient, _lowFeeBps, _highFeeBps, _feeThresholdUSD);
    }

    function _setFeeParams(
        address _feeRecipient,
        uint96 _lowFeeBps,
        uint96 _highFeeBps,
        uint256 _feeThresholdUSD
    ) internal {
        require(_lowFeeBps <= 10_000 && _highFeeBps <= 10_000, "Fee bps too high");

        feeRecipient = _feeRecipient;
        lowFeeBps = _lowFeeBps;
        highFeeBps = _highFeeBps;
        feeThresholdUSD = _feeThresholdUSD;

        emit FeeParamsUpdated(_feeRecipient, _lowFeeBps, _highFeeBps, _feeThresholdUSD);
    }

    // ============ 手续费计算 & 结算 ============

    /**
     * @notice 查询某个拍卖当前按照 V3 规则预计要收取的手续费
     */
    function quoteFee(uint256 auctionId)
        external
        view
        returns (uint256 feeAmount, uint256 sellerAmount, uint96 appliedFeeBps, uint256 usdValue)
    {
        Auction memory auction = auctions[auctionId];
        if (auction.highestBidder == address(0)) {
            return (0, 0, 0, 0);
        }

        usdValue = _getBidUSDValue(auction.highestBid, auction.bidType, auction.bidToken);
        (feeAmount, sellerAmount, appliedFeeBps) = _calculateFee(usdValue, auction.highestBid);
    }

    /**
     * @dev 覆盖 V1/V2 的结算逻辑，加入手续费扣除
     *      注意：函数签名相同，存储布局不变，仅逻辑更换，兼容 UUPS 升级
     */
    function _payoutSeller(Auction storage auction) internal {
        uint256 usdValue = _getBidUSDValue(auction.highestBid, auction.bidType, auction.bidToken);
        (uint256 feeAmount, uint256 sellerAmount, uint96 appliedBps) =
            _calculateFee(usdValue, auction.highestBid);

        address recipient = feeRecipient;

        if (auction.bidType == BidType.ETH) {
            // 收取手续费
            if (feeAmount > 0 && recipient != address(0)) {
                (bool feeOk, ) = recipient.call{value: feeAmount}("");
                require(feeOk, "ETH fee transfer failed");
            }

            // 支付卖家
            (bool sellerOk, ) = auction.seller.call{value: sellerAmount}("");
            require(sellerOk, "ETH payout failed");
        } else {
            IERC20 token = IERC20(auction.bidToken);

            if (feeAmount > 0 && recipient != address(0)) {
                token.transfer(recipient, feeAmount);
            }

            token.transfer(auction.seller, sellerAmount);
        }

        emit FeeCharged(
            auction.highestBidder,
            auction.seller,
            auction.highestBid,
            feeAmount,
            appliedBps,
            auction.bidType,
            auction.bidToken
        );
    }

    /**
     * @dev 根据成交额对应的 USD 值和实际出价金额，计算手续费与卖家实收金额
     */
    function _calculateFee(uint256 usdValue, uint256 amount)
        internal
        view
        returns (uint256 feeAmount, uint256 sellerAmount, uint96 appliedBps)
    {
        // 未设置收款人或费率均为 0，则不收取手续费
        if (feeRecipient == address(0) || (lowFeeBps == 0 && highFeeBps == 0)) {
            return (0, amount, 0);
        }

        // 按成交额的 USD 值选择费率档位
        if (feeThresholdUSD == 0 || usdValue < feeThresholdUSD) {
            appliedBps = lowFeeBps;
        } else {
            appliedBps = highFeeBps;
        }

        if (appliedBps == 0) {
            return (0, amount, 0);
        }

        feeAmount = (amount * appliedBps) / 10_000;
        sellerAmount = amount - feeAmount;
    }

    /**
     * @notice 获取当前实现版本号（V3）
     */
    function getVersionV3() external pure returns (uint256) {
        return VERSION_V3;
    }
}


