// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/MembershipNFT.sol";
import {TokenBoundAccount} from "erc-6551/TokenBoundAccount.sol";
import {EntryPoint, IEntryPoint} from "@thirdweb-dev/contracts/smart-wallet/utils/Entrypoint.sol";
import {MockERC20} from "@thirdweb-dev/src/test/mocks/MockERC20.sol";
import "@erc6551/src/ERC6551Registry.sol";

contract MembershipNFTTest is Test {
    event SharedMetadataUpdated(
        uint256 indexed level,
        string indexed name,
        string description,
        string indexed imageURI,
        string animationURI
    );

    address private sender;
    address private account;
    EntryPoint private entrypoint;
    TokenBoundAccount private tokenboundaccount;
    MockERC20 private mockERC20;
    ERC6551Registry private registry;
    MembershipNFT private membershipContract;
    MembershipNFT.SharedMetadataInfo private metadata;

    function setUp() public {
        sender = makeAddr("sender");
        entrypoint = new EntryPoint();
        // deploy and erc20 token
        mockERC20 = new MockERC20();
        // get the registry address
        registry = new ERC6551Registry();
        tokenboundaccount = new TokenBoundAccount(
            IEntryPoint(payable(address(entrypoint))),
            address(registry)
        );
        // create an instance of the membership nft contract
        membershipContract = new MembershipNFT(
            "Membership NFT",
            "MEM",
            sender,
            0,
            address(tokenboundaccount),
            address(mockERC20),
            address(registry),
            block.chainid
        );
        // mint the key a membership nft
        membershipContract.claim(sender);
        // create a TBA wallet for that nft
        account = registry.createAccount(
            address(tokenboundaccount),
            block.chainid,
            address(mockERC20),
            0,
            0,
            bytes("")
        );
        // set the metadata for level 1
        // ASK how to set the image URI
        metadata.name = "Bronze";
        metadata.description = "This is a bronze level membership";
        metadata.imageURI = "myURI1";
        metadata.animationURI = "myAnimationURI1";
        membershipContract.setSharedMetadata(0, 0, metadata);
    }

    function testSetLevel2Metadata() public {
        metadata.name = "Silver";
        metadata.description = "This is a silver level membership";
        metadata.imageURI = "myURI2";
        metadata.animationURI = "myAnimationURI2";
        membershipContract.setSharedMetadata(1, 0, metadata);
        string memory uri = membershipContract.tokenURI(1);
        assertEq(
            uri,
            NFTMetadataRenderer.createMetadataEdition({
                name: "Silver",
                description: "This is a silver level membership",
                imageURI: "myURI2",
                animationURI: "myAnimationURI2",
                tokenOfEdition: 1
            })
        );
    }

    function testIsLevel1() public {
        // check the metadata for the NFT is correct with balance of 0
        assertEq(membershipContract.ownerOf(0), sender);
        string memory uri = membershipContract.tokenURI(0);
        assertEq(
            uri,
            NFTMetadataRenderer.createMetadataEdition({
                name: "Bronze",
                description: "This is a bronze level membership",
                imageURI: "myURI1",
                animationURI: "myAnimationURI1",
                tokenOfEdition: 0
            })
        );
    }

    function testUpdateLevel() public {
        metadata.name = "Silver";
        metadata.description = "This is a silver level membership";
        metadata.imageURI = "myURI2";
        metadata.animationURI = "myAnimationURI2";
        membershipContract.setSharedMetadata(1, 29, metadata);
        // mint tokens to the wallet
        mockERC20.mint(account, 30);
        // get the updated uri
        string memory uri = membershipContract.tokenURI(0);
        // check the metadata for the NFT has updated
        assertEq(
            uri,
            NFTMetadataRenderer.createMetadataEdition({
                name: "Silver",
                description: "This is a silver level membership",
                imageURI: "myURI2",
                animationURI: "myAnimationURI2",
                tokenOfEdition: 0
            })
        );
    }
}
