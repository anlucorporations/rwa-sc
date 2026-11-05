// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Marketplace} from "../../src/v3/Marketplace.sol";
import {AssetFactory} from "../../src/v3/AssetFactory.sol";
import {AssetNFT721} from "../../src/v3/AssetNFT721.sol";
import {AssetERC1155} from "../../src/v3/AssetERC1155.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockBRLT is ERC20 {
    constructor() ERC20("BRLT", "BRLT") {}
    function mint(address to, uint256 amount) external { _mint(to, amount); }
}

contract MktRegistry {
    mapping(address => bool) public registered;
    mapping(address => address) public identities;
    function set(address a, address id) external { registered[a] = true; identities[a] = id; }
    function isRegistered(address a) external view returns (bool) { return registered[a]; }
    function getIdentity(address a) external view returns (address) { return identities[a]; }
}

contract MktIdentity {
    mapping(uint256 => address[]) internal issuers;
    mapping(uint256 => mapping(address => bool)) internal valid;
    function setClaim(uint256 topic, address issuer) external {
        if (issuers[topic].length == 0) issuers[topic].push(issuer);
        valid[topic][issuer] = true;
    }
    function getClaimIssuersForTopic(uint256 topic) external view returns (address[] memory) { return issuers[topic]; }
    function hasValidClaim(uint256 topic, address issuer) external view returns (bool) { return valid[topic][issuer]; }
}

contract MarketplaceTest is Test {
    MockBRLT internal brlt;
    MktRegistry internal registry;
    MktIdentity internal issuerId;
    MktIdentity internal userIdentity;
    AssetFactory internal factory;
    Marketplace internal market;

    address internal admin = address(0xA11CE);
    address internal issuer = address(0x1550E);
    address internal seller = address(0x5E11E9);
    address internal buyer = address(0xB0B);
    address internal arbiter = address(0xA4B);

    uint256 internal constant GARANTIA = 11;
    uint256 internal constant FIADOR = 12;
    uint256 internal constant KYC = 1;

    function setUp() public {
        brlt = new MockBRLT();
        registry = new MktRegistry();
        issuerId = new MktIdentity();
        userIdentity = new MktIdentity();

        registry.set(issuer, address(issuerId));
        registry.set(seller, address(userIdentity));
        registry.set(buyer, address(userIdentity));
        issuerId.setClaim(GARANTIA, address(0xAA));
        issuerId.setClaim(FIADOR, address(0xAA));
        userIdentity.setClaim(KYC, address(0xAA));

        factory = new AssetFactory(admin, address(registry), GARANTIA, FIADOR);
        market = new Marketplace(admin, address(brlt));
        vm.prank(admin);
        market.setTokenApproved(address(0), false);
        bytes32 arbiterRole = market.ARBITER_ROLE();
        vm.prank(admin);
        market.grantRole(arbiterRole, arbiter);
        brlt.mint(buyer, 1_000_000 ether);
    }

    function _create721() internal returns (AssetNFT721 token, uint256 tokenId) {
        uint256[] memory topics = new uint256[](1);
        topics[0] = KYC;
        vm.prank(admin);
        token = AssetNFT721(factory.createNFT721("Bien", "BIEN", "good", issuer, topics));
        vm.prank(issuer);
        tokenId = token.mint(seller, "ipfs://x", false);
        vm.prank(issuer);
        token.setEscrowOperator(address(market), true);
        vm.prank(admin);
        market.setTokenApproved(address(token), true);
    }

    function _create1155() internal returns (AssetERC1155 token) {
        uint256[] memory topics = new uint256[](1);
        topics[0] = KYC;
        vm.prank(admin);
        token = AssetERC1155(factory.createERC1155("ipfs://{id}.json", "product", issuer, topics));
        vm.prank(issuer);
        token.mintNew(seller, 10, "");
        vm.prank(issuer);
        token.setEscrowOperator(address(market), true);
        vm.prank(admin);
        market.setTokenApproved(address(token), true);
    }

    function _list721(uint256 price) internal returns (uint256 id) {
        (AssetNFT721 token, uint256 tokenId) = _create721();
        vm.prank(seller);
        token.approve(address(market), tokenId);
        vm.prank(seller);
        id = market.createListing(address(token), tokenId, 1, price, false);
    }

    function test_crear_listado_escrowa_el_activo() public {
        uint256 id = _list721(100 ether);
        Marketplace.Listing memory l = market.getListing(id);
        assertEq(l.seller, seller);
        assertEq(l.price, 100 ether);
        assertEq(uint256(l.state), uint256(Marketplace.State.Active));
        AssetNFT721 token = AssetNFT721(l.token);
        assertEq(token.ownerOf(l.tokenId), address(market));
    }

    function test_compra_escrowa_brlt_y_confirmacion_libera() public {
        uint256 id = _list721(100 ether);
        vm.startPrank(buyer);
        brlt.approve(address(market), 100 ether);
        market.buy(id);
        vm.stopPrank();
        Marketplace.Listing memory l = market.getListing(id);
        assertEq(uint256(l.state), uint256(Marketplace.State.Funded));
        assertEq(brlt.balanceOf(address(market)), 100 ether);

        vm.prank(buyer);
        market.confirmReceipt(id);
        l = market.getListing(id);
        assertEq(uint256(l.state), uint256(Marketplace.State.Completed));
        assertEq(brlt.balanceOf(seller), 100 ether);
        assertEq(AssetNFT721(l.token).ownerOf(l.tokenId), buyer);
    }

    function test_cancelar_devuelve_el_activo() public {
        uint256 id = _list721(100 ether);
        Marketplace.Listing memory l = market.getListing(id);
        vm.prank(seller);
        market.cancelListing(id);
        assertEq(uint256(market.getListing(id).state), uint256(Marketplace.State.Cancelled));
        assertEq(AssetNFT721(l.token).ownerOf(l.tokenId), seller);
    }

    function test_disputa_libera_al_vendedor() public {
        uint256 id = _list721(100 ether);
        vm.startPrank(buyer);
        brlt.approve(address(market), 100 ether);
        market.buy(id);
        market.openDispute(id);
        vm.stopPrank();
        Marketplace.Listing memory l = market.getListing(id);
        vm.prank(arbiter);
        market.resolveDispute(id, true);
        assertEq(brlt.balanceOf(seller), 100 ether);
        assertEq(AssetNFT721(l.token).ownerOf(l.tokenId), buyer);
    }

    function test_disputa_reembolsa_al_comprador() public {
        uint256 id = _list721(100 ether);
        vm.startPrank(buyer);
        brlt.approve(address(market), 100 ether);
        market.buy(id);
        market.openDispute(id);
        vm.stopPrank();
        Marketplace.Listing memory l = market.getListing(id);
        uint256 before = brlt.balanceOf(buyer);
        vm.prank(arbiter);
        market.resolveDispute(id, false);
        assertEq(brlt.balanceOf(buyer), before + 100 ether);
        assertEq(AssetNFT721(l.token).ownerOf(l.tokenId), seller);
    }

    function test_solo_arbitro_resuelve() public {
        uint256 id = _list721(100 ether);
        vm.startPrank(buyer);
        brlt.approve(address(market), 100 ether);
        market.buy(id);
        market.openDispute(id);
        vm.stopPrank();
        vm.prank(buyer);
        vm.expectRevert();
        market.resolveDispute(id, true);
    }

    function test_no_se_compra_dos_veces() public {
        uint256 id = _list721(100 ether);
        vm.startPrank(buyer);
        brlt.approve(address(market), 200 ether);
        market.buy(id);
        vm.expectRevert(Marketplace.InvalidState.selector);
        market.buy(id);
        vm.stopPrank();
    }

    function test_token_no_aprobado_revierte() public {
        (AssetNFT721 token, uint256 tokenId) = _create721();
        vm.prank(admin);
        market.setTokenApproved(address(token), false);
        vm.prank(seller);
        token.approve(address(market), tokenId);
        vm.prank(seller);
        vm.expectRevert(Marketplace.TokenNotApproved.selector);
        market.createListing(address(token), tokenId, 1, 100 ether, false);
    }

    function test_flujo_erc1155() public {
        AssetERC1155 token = _create1155();
        vm.prank(seller);
        token.setApprovalForAll(address(market), true);
        vm.prank(seller);
        uint256 id = market.createListing(address(token), 1, 10, 50 ether, true);
        vm.startPrank(buyer);
        brlt.approve(address(market), 50 ether);
        market.buy(id);
        market.confirmReceipt(id);
        vm.stopPrank();
        assertEq(token.balanceOf(buyer, 1), 10);
        assertEq(brlt.balanceOf(seller), 50 ether);
    }

    function test_comprador_no_elegible_no_recibe_activo() public {
        uint256 id = _list721(100 ether);
        address stranger = address(0xDEAD);
        brlt.mint(stranger, 100 ether);
        vm.startPrank(stranger);
        brlt.approve(address(market), 100 ether);
        market.buy(id);
        vm.expectRevert();
        market.confirmReceipt(id);
        vm.stopPrank();
    }
}
