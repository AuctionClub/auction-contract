// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {DutchAuction} from "../src/DutchAuction.sol";
import {MyNFT} from "../src/MyNFT.sol";

contract DutchAuction_test is Test {
    DutchAuction dutch;
    MyNFT nft;
    address admin = makeAddr("admin");
    address seller = makeAddr("seller");
    address bidder = makeAddr("bidder");

    function setUp() public {
        vm.startPrank(admin);
        dutch = new DutchAuction();
        nft = new MyNFT();        
        vm.stopPrank();
        deal(seller, 100000 ether);
        deal(bidder, 100000 ether);
        nftOperate();
        console.log("seller:", seller); 
        console.log("bidder:", bidder);
    }

    function nftOperate() public {
        vm.startPrank(admin);
        nft.mint(seller, "http://www.baidu.com");
        vm.stopPrank();

        vm.startPrank(seller);
        nft.approve(address(dutch), 1);
        vm.stopPrank();
    }

    function test_bid_auction() public {
        vm.startPrank(seller);
        {
            uint256 startingPrice = 100 ether;
            uint256 startTime = block.timestamp;
            uint256 price_decay_interval = 100;
            uint256 price_decay_amount = 1;
            uint256 reserve_duration = 100;
            dutch.startAuction(address(nft), 1, startingPrice, 1, startTime, price_decay_interval, price_decay_amount, reserve_duration);
            //get_auctionInfo(0);
        }
        vm.stopPrank();

        vm.startPrank(bidder);
        {
    
            console.log("owner bid before:", nft.ownerOf(1));
            dutch.bid{value: 100 ether}(1);
            console.log("owner bid after:", nft.ownerOf(1));
        }
        vm.stopPrank();

    }


    // function get_auctionInfo(uint auctionID) public {
        
    //     (
    //         address aseller,
    //         address nftAddress,
    //         uint256 nftTokenId,
    //         uint256 startingPrice,
    //         uint256 currentHighestBid,
    //         address currentHighestBidder,
    //         bool ended,
    //         uint256 totalBidAmount,
    //         uint256 startTime,
    //         uint256 endTime,
    //         uint256 interval
    //     ) = british.auctions(auctionID);

    //     console.log(aseller);
    //     console.log(nftAddress);
    //     console.log(nftTokenId);
    //     console.log(startingPrice);
    //     console.log(currentHighestBid);
    //     console.log(currentHighestBidder);
    //     console.log(ended);
    //     console.log(totalBidAmount);
    //     console.log(startTime);
    //     console.log(endTime);
    //     console.log(interval);
        
    // }

    
}