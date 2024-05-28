// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {BritishAuction} from "../src/BritishAuction.sol";
import {MyNFT} from "../src/MyNFT.sol";

contract BritishAuction_test is Test {
    BritishAuction british;
    MyNFT nft;
    address admin = makeAddr("admin");
    address seller = makeAddr("seller");
    address bidder = makeAddr("bidder");

    function setUp() public {
        vm.startPrank(admin);
        british = new BritishAuction(payable(admin));
        nft = new MyNFT();        
        vm.stopPrank();
        deal(seller, 100000 ether);
        deal(bidder, 100000 ether);
        nftOperate();
    }

    function nftOperate() public {
        vm.startPrank(admin);
        nft.mint(seller, "http://www.baidu.com");
        vm.stopPrank();

        vm.startPrank(seller);
        nft.approve(address(british), 1);
        vm.stopPrank();
    }

    function test_create_auction() public {
        vm.startPrank(seller);
        {
            uint256 startingPrice = 100 ether;
            uint256 startTime = block.timestamp ;
            british.createAuction(startingPrice, startTime, address(nft), 1, 10000);
            get_auctionInfo(0);
        }
        vm.stopPrank();

        vm.startPrank(bidder);
        {
            (bool success, ) = address(british).call{value: 1000 ether}("");
            require(british.balances(bidder) == 1000 ether, "balance wrong");
            
            british.reserve{value: 1000 ether}();
            require(british.balances(bidder) == 2000 ether, "reserve wrong");

            british.bid(0, 500 ether);
            require(british.balances(bidder) == 1500 ether, "bid wrong");

            british.bid{value: 300 ether}(0, 600 ether);
            require(british.balances(bidder) == 1700 ether, "bid wrong");
            get_auctionInfo(0);
        }
        vm.stopPrank();


        vm.startPrank(seller);
        {
            british.cancelAuction(0);
            get_auctionInfo(0);
            require(british.balances(bidder) == 2300 ether, "return fund wrong");

        }
        vm.stopPrank();

        vm.startPrank(bidder);
        {
            british.withdrawBalance(1000 ether);
            require(british.balances(bidder) == 1300 ether, "withdraw fund wrong");
        }
        vm.stopPrank();



    }


    function get_auctionInfo(uint auctionID) public {
        
        (
            address aseller,
            address nftAddress,
            uint256 nftTokenId,
            uint256 startingPrice,
            uint256 currentHighestBid,
            address currentHighestBidder,
            bool ended,
            uint256 totalBidAmount,
            uint256 startTime,
            uint256 endTime,
            uint256 interval
        ) = british.auctions(auctionID);

        console.log(aseller);
        console.log(nftAddress);
        console.log(nftTokenId);
        console.log(startingPrice);
        console.log(currentHighestBid);
        console.log(currentHighestBidder);
        console.log(ended);
        console.log(totalBidAmount);
        console.log(startTime);
        console.log(endTime);
        console.log(interval);
        
    }

    
}