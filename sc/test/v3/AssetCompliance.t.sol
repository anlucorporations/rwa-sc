// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AssetFactory} from "../../src/v3/AssetFactory.sol";
import {AssetNFT721} from "../../src/v3/AssetNFT721.sol";
import {AssetERC1155} from "../../src/v3/AssetERC1155.sol";
import {AssetComplianceHook} from "../../src/v3/AssetComplianceHook.sol";

/// @dev Registro de identidades mínimo (v2-like).
contract MockRegistry {
    mapping(address => bool) public registered;
    mapping(address => address) public identities;

    function set(address account, address identity) external {
        registered[account] = true;
        identities[account] = identity;
    }

    function isRegistered(address account) external view returns (bool) {
        return registered[account];
    }

    function getIdentity(address account) external view returns (address) {
        return identities[account];
    }
}

/// @dev Identity mínimo con claims por topic.
contract MockIdentity {
    mapping(uint256 => address[]) internal issuers;
    mapping(uint256 => mapping(address => bool)) internal valid;

    function setClaim(uint256 topic, address issuer, bool ok) external {
        if (issuers[topic].length == 0) issuers[topic].push(issuer);
        valid[topic][issuer] = ok;
    }

    function getClaimIssuersForTopic(uint256 topic) external view returns (address[] memory) {
        return issuers[topic];
    }

    function hasValidClaim(uint256 topic, address issuer) external view returns (bool) {
        return valid[topic][issuer];
    }
}

contract AssetComplianceTest is Test {
    MockRegistry internal registry;
    MockIdentity internal issuerIdentity;
    MockIdentity internal userIdentity;
    MockIdentity internal otherIdentity;
    AssetFactory internal factory;

    address internal admin = address(0xA11CE);
    address internal issuer = address(0x1550E);
    address internal verifiedUser = address(0xB0B);
    address internal otherUser = address(0xCAFE);

    uint256 internal constant GARANTIA = 11;
    uint256 internal constant FIADOR = 12;
    uint256 internal constant KYC = 1;

    function setUp() public {
        registry = new MockRegistry();
        issuerIdentity = new MockIdentity();
        userIdentity = new MockIdentity();
        otherIdentity = new MockIdentity();

        registry.set(issuer, address(issuerIdentity));
        registry.set(verifiedUser, address(userIdentity));
        registry.set(otherUser, address(otherIdentity)); // registrado pero sin claims

        issuerIdentity.setClaim(GARANTIA, address(0xAA), true);
        issuerIdentity.setClaim(FIADOR, address(0xAA), true);
        userIdentity.setClaim(KYC, address(0xAA), true);

        factory = new AssetFactory(admin, address(registry), GARANTIA, FIADOR);
    }

    function _mint(AssetNFT721 token, address to, string memory uri, bool isService) internal returns (uint256) {
        vm.prank(issuer);
        return token.mint(to, uri, isService);
    }

    function _create721() internal returns (AssetNFT721 token) {
        uint256[] memory topics = new uint256[](1);
        topics[0] = KYC;
        vm.prank(admin);
        token = AssetNFT721(factory.createNFT721("Bien", "BIEN", "good", issuer, topics));
    }

    function test_factory_rechaza_emisor_sin_garantia_y_fiador() public {
        MockIdentity sinClaims = new MockIdentity();
        address issuer2 = address(0xDEAD);
        registry.set(issuer2, address(sinClaims));
        uint256[] memory topics = new uint256[](0);
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(AssetFactory.IssuerNotEligible.selector, issuer2, GARANTIA));
        factory.createNFT721("X", "X", "good", issuer2, topics);
    }

    function test_factory_crea_activo_con_emisor_elegible() public {
        AssetNFT721 token = _create721();
        assertTrue(factory.isAsset(address(token)));
        assertEq(factory.assetsCount(), 1);
        assertEq(token.assetKind(), "good");
    }

    function test_mint_rechaza_receptor_sin_claims() public {
        AssetNFT721 token = _create721();
        vm.expectRevert(abi.encodeWithSelector(AssetComplianceHook.ReceiverNotVerified.selector, otherUser, KYC));
        vm.prank(issuer);
        token.mint(otherUser, "ipfs://x", false);
    }

    function test_mint_acepta_receptor_verificado() public {
        AssetNFT721 token = _create721();
        uint256 id = _mint(token, verifiedUser, "ipfs://x", false);
        assertEq(token.ownerOf(id), verifiedUser);
    }

    function test_transferencia_a_no_verificado_revierte() public {
        AssetNFT721 token = _create721();
        uint256 id = _mint(token, verifiedUser, "ipfs://x", false);
        vm.prank(verifiedUser);
        vm.expectRevert(abi.encodeWithSelector(AssetComplianceHook.ReceiverNotVerified.selector, otherUser, KYC));
        token.transferFrom(verifiedUser, otherUser, id);
    }

    function test_consumo_de_servicio_quema_nft() public {
        uint256[] memory topics = new uint256[](0);
        vm.prank(admin);
        AssetNFT721 token = AssetNFT721(factory.createNFT721("Servicio", "SRV", "service", issuer, topics));
        uint256 id = _mint(token, verifiedUser, "ipfs://s", true);
        vm.prank(verifiedUser);
        token.consumeService(id);
        vm.expectRevert();
        token.ownerOf(id);
    }

    function test_consumo_solo_titular_y_solo_servicio() public {
        AssetNFT721 token = _create721();
        uint256 id = _mint(token, verifiedUser, "ipfs://x", false);
        vm.prank(verifiedUser);
        vm.expectRevert(bytes("no es servicio"));
        token.consumeService(id);

        uint256[] memory topics = new uint256[](0);
        vm.prank(admin);
        AssetNFT721 svc = AssetNFT721(factory.createNFT721("S2", "S2", "service", issuer, topics));
        vm.prank(issuer);
        uint256 sid = svc.mint(verifiedUser, "ipfs://s", true);
        vm.prank(otherUser);
        vm.expectRevert(bytes("solo el titular"));
        svc.consumeService(sid);
    }

    function test_erc1155_mint_y_transferencia_con_compliance() public {
        uint256[] memory topics = new uint256[](1);
        topics[0] = KYC;
        vm.prank(admin);
        AssetERC1155 token = AssetERC1155(factory.createERC1155("ipfs://{id}.json", "product", issuer, topics));
        vm.prank(issuer);
        uint256 id = token.mintNew(verifiedUser, 100, "");
        assertEq(token.balanceOf(verifiedUser, id), 100);

        vm.prank(verifiedUser);
        vm.expectRevert(abi.encodeWithSelector(AssetComplianceHook.ReceiverNotVerified.selector, otherUser, KYC));
        token.safeTransferFrom(verifiedUser, otherUser, id, 1, "");
    }

    function test_fail_closed_sin_registry() public {
        uint256[] memory topics = new uint256[](0);
        AssetNFT721 token = new AssetNFT721("A", "A", "good", admin, address(0), topics);
        assertFalse(token.isEligible(verifiedUser));
        vm.expectRevert(AssetComplianceHook.RegistryNotConfigured.selector);
        vm.prank(admin);
        token.mint(verifiedUser, "ipfs://x", false);
    }
}
