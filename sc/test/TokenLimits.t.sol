// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {TokenCloneable} from "../src/TokenCloneable.sol";
import {IdentityCloneable} from "../src/IdentityCloneable.sol";
import {TokenCloneFactory} from "../src/TokenCloneFactory.sol";
import {IdentityCloneFactory} from "../src/IdentityCloneFactory.sol";
import {IdentityRegistry} from "../src/IdentityRegistry.sol";
import {TrustedIssuersRegistry} from "../src/TrustedIssuersRegistry.sol";
import {ClaimTopicsRegistry} from "../src/ClaimTopicsRegistry.sol";
import {ICompliance} from "../src/ICompliance.sol";
import {SigUtils} from "./helpers/SigUtils.sol";

/**
 * @title SpyComplianceModule
 * @notice Modulo de compliance que solo cuenta notificaciones (para probar `destroyed`, RF-004/CU-06 #4).
 */
contract SpyComplianceModule is ICompliance {
    uint256 public destroyedCount;
    uint256 public transferredCount;
    uint256 public createdCount;

    function canTransfer(address, address, uint256) external pure returns (bool) {
        return true;
    }

    /// @dev RF-003: el token valida ERC-165 al dar de alta el modulo.
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(ICompliance).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    function transferred(address, address, uint256) external {
        transferredCount++;
    }

    function created(address, uint256) external {
        createdCount++;
    }

    function destroyed(address, uint256) external {
        destroyedCount++;
    }
}

/**
 * @title TokenLimitsTest
 * @notice Pruebas de RF-004 (Ciclo 5) segun CU-06: whitelist de destinos para `forcedTransfer`,
 * topes por operacion (`maxBurnPerTx`, `maxForcedPerTx`, con `0` = operacion desactivada) y tope de
 * suministro administrable (`maxSupply`, con `0` = sin tope, D-022).
 */
contract TokenLimitsTest is Test {
    uint256 internal constant ISSUER_PK = 0xA11CE;
    uint256 internal constant KYC_TOPIC = 1;
    /// @dev D-038: `expiresAt == 0` significa sin caducidad.
    uint256 internal constant EXPIRES_AT = 0;

    address internal admin = address(this);
    address internal issuer;
    address internal user1;
    address internal user2;
    address internal stranger;

    TokenCloneable internal token;
    IdentityRegistry internal identityRegistry;
    TrustedIssuersRegistry internal trustedIssuersRegistry;
    ClaimTopicsRegistry internal claimTopicsRegistry;

    event DestinationAuthorized(address indexed destination, bool authorized);
    event LimitsUpdated(uint256 maxBurnPerTx, uint256 maxForcedPerTx);
    event MaxSupplyUpdated(uint256 maxSupply);

    function setUp() public {
        issuer = vm.addr(ISSUER_PK);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        stranger = makeAddr("stranger");

        TokenCloneFactory tokenFactory = new TokenCloneFactory(admin);
        IdentityCloneFactory identityFactory = new IdentityCloneFactory(admin);

        token = TokenCloneable(tokenFactory.createToken("Limits Token", "LIM", 18, admin));

        identityRegistry = new IdentityRegistry(admin);
        trustedIssuersRegistry = new TrustedIssuersRegistry(admin);
        claimTopicsRegistry = new ClaimTopicsRegistry(admin);

        token.setIdentityRegistry(address(identityRegistry));
        token.setTrustedIssuersRegistry(address(trustedIssuersRegistry));
        token.setClaimTopicsRegistry(address(claimTopicsRegistry));

        uint256[] memory topics = new uint256[](1);
        topics[0] = KYC_TOPIC;
        trustedIssuersRegistry.addTrustedIssuer(issuer, topics);
        claimTopicsRegistry.addClaimTopic(KYC_TOPIC);

        _registerVerified(identityFactory, user1);
        _registerVerified(identityFactory, user2);
    }

    function _registerVerified(IdentityCloneFactory identityFactory, address wallet) internal {
        IdentityCloneable identity = IdentityCloneable(identityFactory.createIdentity(admin));
        bytes memory kycData = abi.encode("KYC", address(identity));
        identity.addClaim(
            KYC_TOPIC,
            1,
            issuer,
            SigUtils.signClaim(ISSUER_PK, address(identity), admin, KYC_TOPIC, 1, kycData, EXPIRES_AT),
            kycData,
            "",
            EXPIRES_AT
        );
        identityRegistry.registerIdentity(wallet, address(identity));
    }

    // ================= CU-06: burn acotado por maxBurnPerTx =================

    function test_RF004_burn_dentro_del_limite_ok() public {
        token.setMaxBurnPerTx(100);
        token.mint(user1, 100);

        token.burn(user1, 100);

        assertEq(token.balanceOf(user1), 0);
        assertEq(token.totalSupply(), 0);
    }

    function test_RF004_burn_excede_limite_revierte() public {
        token.setMaxBurnPerTx(100);
        token.mint(user1, 200);

        vm.expectRevert("Exceeds max burn per tx");
        token.burn(user1, 101);

        assertEq(token.balanceOf(user1), 200);
        assertEq(token.totalSupply(), 200);
    }

    function test_RF004_burn_notifica_modulos() public {
        SpyComplianceModule spy = new SpyComplianceModule();
        token.addComplianceModule(address(spy));
        token.setMaxBurnPerTx(100);
        token.mint(user1, 100);

        token.burn(user1, 40);

        assertEq(spy.destroyedCount(), 1);
    }

    /// EARS: el tope es por operacion, no acumulado.
    function test_RF004_limite_es_por_operacion_no_acumulado() public {
        token.setMaxBurnPerTx(100);
        token.mint(user1, 300);

        token.burn(user1, 100);
        token.burn(user1, 100);
        token.burn(user1, 100);

        assertEq(token.balanceOf(user1), 0);
        assertEq(token.totalSupply(), 0);
    }

    /// EARS: `0` desactiva la operacion (fail-closed).
    function test_RF004_limites_zero_bloquean() public {
        assertEq(token.maxBurnPerTx(), 0, "maxBurnPerTx por defecto debe ser 0");
        token.mint(user1, 100);
        vm.expectRevert("Exceeds max burn per tx");
        token.burn(user1, 1);

        assertEq(token.maxForcedPerTx(), 0, "maxForcedPerTx por defecto debe ser 0");
        token.setAuthorizedDestination(user2, true);
        vm.expectRevert("Exceeds max forced transfer per tx");
        token.forcedTransfer(user1, user2, 1);
    }

    // ================= CU-04/CU-06: whitelist de destinos =================

    function test_RF004_forcedTransfer_destino_no_autorizado_revierte() public {
        token.setMaxForcedPerTx(1000);
        token.mint(user1, 100);

        vm.expectRevert("Destination not authorized");
        token.forcedTransfer(user1, user2, 50);

        assertEq(token.balanceOf(user2), 0);
    }

    function test_RF004_whitelist_revocada_bloquea() public {
        token.setMaxForcedPerTx(1000);
        token.setAuthorizedDestination(user2, true);
        token.mint(user1, 100);

        token.forcedTransfer(user1, user2, 40);
        assertEq(token.balanceOf(user2), 40);

        token.setAuthorizedDestination(user2, false);
        vm.expectRevert("Destination not authorized");
        token.forcedTransfer(user1, user2, 10);
        assertEq(token.balanceOf(user2), 40);
    }

    function test_RF004_forcedTransfer_dentro_del_limite_ok() public {
        token.setAuthorizedDestination(user2, true);
        token.setMaxForcedPerTx(100);
        token.mint(user1, 100);

        token.forcedTransfer(user1, user2, 100);

        assertEq(token.balanceOf(user2), 100);
        assertEq(token.balanceOf(user1), 0);
    }

    function test_RF004_forcedTransfer_excede_limite_revierte() public {
        token.setAuthorizedDestination(user2, true);
        token.setMaxForcedPerTx(100);
        token.mint(user1, 200);

        vm.expectRevert("Exceeds max forced transfer per tx");
        token.forcedTransfer(user1, user2, 101);

        assertEq(token.balanceOf(user2), 0);
    }

    // ================= control de acceso de los setters =================

    function test_RF004_setAuthorizedDestination_solo_admin_o_compliance() public {
        vm.prank(stranger);
        vm.expectRevert("Not authorized");
        token.setAuthorizedDestination(user2, true);

        assertFalse(token.authorizedDestinations(user2));
    }

    function test_RF004_setLimits_compliance_ok() public {
        address compliance = makeAddr("compliance");
        token.grantRole(token.COMPLIANCE_ROLE(), compliance);

        vm.prank(compliance);
        token.setMaxBurnPerTx(7);
        vm.prank(compliance);
        token.setMaxForcedPerTx(9);

        assertEq(token.maxBurnPerTx(), 7);
        assertEq(token.maxForcedPerTx(), 9);
    }

    function test_RF004_setMaxSupply_solo_admin() public {
        vm.prank(stranger);
        vm.expectRevert();
        token.setMaxSupply(100);

        assertEq(token.maxSupply(), 0);
    }

    // ================= maxSupply (D-022) =================

    function test_RF004_maxSupply_impide_exceder() public {
        token.setMaxSupply(150);
        token.mint(user1, 100);

        vm.expectRevert("Max supply exceeded");
        token.mint(user2, 51);

        assertEq(token.totalSupply(), 100);
    }

    function test_RF004_maxSupply_no_baja_bajo_total_supply() public {
        token.mint(user1, 100);

        vm.expectRevert("Max supply below total supply");
        token.setMaxSupply(99);

        assertEq(token.maxSupply(), 0);
    }

    function test_RF004_maxSupply_cero_sin_tope() public {
        token.setMaxSupply(0);
        token.mint(user1, 1_000_000 ether);

        assertEq(token.totalSupply(), 1_000_000 ether);
    }

    function test_RF004_maxSupply_en_el_limite_ok() public {
        token.setMaxSupply(100);
        token.mint(user1, 100);

        assertEq(token.totalSupply(), 100);
    }

    // ================= eventos =================

    function test_RF004_setters_emiten_eventos() public {
        vm.expectEmit(true, false, false, true, address(token));
        emit DestinationAuthorized(user2, true);
        token.setAuthorizedDestination(user2, true);

        vm.expectEmit(false, false, false, true, address(token));
        emit LimitsUpdated(100, 0);
        token.setMaxBurnPerTx(100);

        vm.expectEmit(false, false, false, true, address(token));
        emit LimitsUpdated(100, 50);
        token.setMaxForcedPerTx(50);

        vm.expectEmit(false, false, false, true, address(token));
        emit MaxSupplyUpdated(1000);
        token.setMaxSupply(1000);
    }
}
