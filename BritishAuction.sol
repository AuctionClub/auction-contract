// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8//AutomationCompatible.sol";
contract BritishAuction is AutomationCompatibleInterface{
    struct AuctionItem {
        address seller; // 卖家地址
        address nftAddress; // NFT合约地址
        uint256 nftTokenId; // NFT Token ID
        uint256 startingPrice; // 起拍价
        uint256 currentHighestBid; // 当前最高出价
        address currentHighestBidder; // 当前最高出价者地址
        bool ended; // 拍卖是否结束
        uint256 totalBidAmount; // 总出价金额
        mapping(address => uint256) bidAmounts; // 每个竞拍者的出价金额
        address[] bidders; // 竞拍者列表
        uint256 startTime; // 拍卖开始时间
        uint266 endTime; // 拍卖结束时间    
        uint256 interval; // 拍卖间隔

    }

    mapping(uint256 => AuctionItem) public auctions; // 拍卖ID与拍卖物品的映射
    mapping(address => uint256) public pendingReturns; // 竞拍者待领取的金额
    uint256 public nextAuctionId; // 下一个拍卖ID
    address payable public platformAddress; // 平台地址
    mapping(address => uint256) public balances; // 竞拍者个人中心余额

    event AuctionCreated(uint256 auctionId, address seller, uint256 startingPrice, uint256 _startTime); // 拍卖创建事件
    event HighestBidIncreased(uint256 auctionId, address bidder, uint256 amount); // 最高出价增加事件
    event AuctionEnded(uint256 auctionId, address winner, uint256 amount); // 拍卖结束事件
    event AuctionCancelled(uint256 auctionId); // 拍卖取消事件
    event RewardDistributed(uint256 auctionId, address bidder, uint256 reward); // 奖励分发事件
    event ReserveAdded(address indexed user, uint256 amount); // 添加余额事件

    constructor(address payable _platformAddress) {
        platformAddress = _platformAddress; // 设置平台地址
    }

    function createAuction(uint256 _startingPrice, uint256 _startTime,  address nftAddress, uint256 nftTokenId, uint256 interval) public payable {
        // 创建拍卖，要求卖家质押起拍价的20%
        require(msg.value >= (_startingPrice * 20 / 100), "Deposit must be at least 20% of starting price");
        require(_startTime > block.timestamp, "Start time must be in the future");

        AuctionItem storage newItem = auctions[nextAuctionId];
        nextAuctionId++;
        newItem.seller = msg.sender;
        newItem.startingPrice = _startingPrice;
        newItem.ended = false;
        newItem.startTime = _startTime;
        newItem.nftAddress = nftAddress;
        newItem.nftTokenId = nftTokenId;
        newItem.interval = interval;
        emit AuctionCreated(nextAuctionId, msg.sender, _startingPrice, _startTime); // 触发拍卖创建事件
    }

    function bid(uint256 _itemId, uint256 bitAmount) public payable {
        // 进行竞拍
        AuctionItem storage item = auctions[_itemId];
        require(block.timestamp >= item.startTime, "Auction has not started yet"); // 确认拍卖已开始
        require(!item.ended, "Auction already ended"); // 确认拍卖未结束
        require(bitAmount < msg.value + balances[msg.sender], "Insufficient balance"); // 确认余额足够
        require(bitAmount > item.currentHighestBid, "There already is a higher bid"); // 确认出价高于当前最高出价
        
        balances[msg.sender] += msg.value; // 将用户余额增加
        uint256 previousBid = item.bidAmounts[msg.sender]; // 之前的出价金额

        uint256 additionalBid = bitAmount - previousBid; // 额外出价金额
        if (previousBid > 0) {
            item.totalBidAmount += additionalBid; // 更新总出价金额
        } else {
            item.totalBidAmount += additionalBid; // 更新总出价金额
            item.bidders.push(msg.sender); // 将新的竞拍者添加到竞拍者列表中
        }

        item.bidAmounts[msg.sender] = bitAmount; // 更新竞拍者的出价金额
        item.currentHighestBid = bitAmount; // 更新当前最高出价
        item.currentHighestBidder = msg.sender; // 更新当前最高出价者

        balances[msg.sender] -= additionalBid; // 更新用户余额，未使用的部分会在竞拍结束时返还
        item.endTime = block.timestamp + item.interval; // 更新拍卖结束时间
        emit HighestBidIncreased(_itemId, msg.sender, msgSenderHighestBid); // 触发最高出价增加事件
    }


    function cancelAuction(uint256 _itemId) public {
        // 取消拍卖
        AuctionItem storage item = auctions[_itemId];
        require(msg.sender == item.seller, "Only seller can cancel the auction"); // 确认只有卖家可以取消拍卖
        require(!item.ended, "Auction already ended"); // 确认拍卖未结束

        // 罚金为起拍价的20%的10%
        uint256 penaltyAmount = (item.startingPrice * 20 / 100) * 10 / 100;
        platformAddress.transfer(penaltyAmount); // 将罚金转入平台地址

        item.ended = true;
        emit AuctionCancelled(_itemId); // 触发拍卖取消事件
    }

    function endAuction(uint256 _itemId) internal {
        // 结束拍卖
        AuctionItem storage item = auctions[_itemId];
        require(msg.sender == item.seller, "Only seller can end the auction"); // 确认只有卖家可以结束拍卖
        require(!item.ended, "Auction already ended"); // 确认拍卖未结束

        uint256 totalAmount = item.currentHighestBid; // 总成交金额
        uint256 platformFee = totalAmount * 2 / 100; // 平台手续费2%
        uint256 sellerAmount = totalAmount * 95 / 100; // 卖家所得金额95%
        uint256 pre_bidderReward = totalAmount * 3 / 100; // 竞拍者奖励金额3%

        // 从竞拍者列表中移除当前最高出价者（最后的成交者）
        for (uint i = 0; i < item.bidders.length; i++) {
            if (item.bidders[i] == item.currentHighestBidder) {
                item.bidders[i] = item.bidders[item.bidders.length - 1];
                item.bidders.pop();
                break;
            }
        }

        // 分配奖励
        for (uint i = 0; i < item.bidders.length; i++) {
            address bidder = item.bidders[i];
            uint256 bidderReward = item.bidAmounts[bidder] + (item.bidAmounts[bidder] * pre_bidderReward) / item.totalBidAmount; // 按比例分配
            pendingReturns[bidder] = bidderReward;
            emit RewardDistributed(_itemId, bidder, bidderReward); // 触发奖励分发事件
        }
        platformAddress.transfer(platformFee); // 转移平台手续费
        payable(item.seller).transfer(sellerAmount); // 转移卖家所得金额

        item.ended = true;
        emit AuctionEnded(_itemId, item.currentHighestBidder, totalAmount); // 触发拍卖结束事件
    }

    //提取balance的余额
    function withdrawBalance() public {
        uint256 balanceAmount = balances[msg.sender];

        require(balanceAmount > 0, "No balance"); // 确认有待领取金额或个人中心余额

        balances[msg.sender] = 0;
        payable(msg.sender).transfer(balanceAmount); // 转移待领取金额和个人中心余额到竞拍者地址
    }

    //提取拍卖结束的pendingReturns余额
    function withdrawPendingReturns() public {
        uint256 amount = pendingReturns[msg.sender];
        pendingReturns[msg.sender] = 0;

        payable(msg.sender).transfer(amount); // 转移待领取金额到竞拍者地址
    }


    function reserve() public payable {
        require(msg.value > 0, "Must send ETH to add to reserve");
        balances[msg.sender] += msg.value;
        emit ReserveAdded(msg.sender, msg.value); // 触发添加余额事件
    }

    function getBalance() public view returns (uint256) {
        // 获取个人中心余额
        return balances[msg.sender];
    }

    receive() external payable {
        // 处理接收的ETH
        balances[msg.sender] += msg.value;
        emit ReserveAdded(msg.sender, msg.value); // 触发添加余额事件
    }

   function checkUpkeep(bytes calldata checkData) external view override returns (bool upkeepNeeded, bytes memory performData) {
        upkeepNeeded = false;
        uint256 auctionId;
        uint256 intervalTime;

        // 遍历拍卖ID列表，检查是否有拍卖需要结束
        for (uint256 i = 0; i < nextAuctionId; i++) {
            AuctionItem storage item = auctions[i];
            intervalTime = item.interval;

            if (block.timestamp > item.endTime && !item.ended) {
                upkeepNeeded = true;
                performData = abi.encode(auctionId);
                break;
            }
        }
    }

    function performUpkeep(bytes calldata ) external { 
        uint256 auctionId = abi.decode(performData, (uint256));
        endAuction(auctionId);
    }
}