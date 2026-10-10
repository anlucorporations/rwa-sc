// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {TokenCloneFactory} from "../src/TokenCloneFactory.sol";
import {TokenCloneable} from "../src/TokenCloneable.sol";
import {TokenBenchmark} from "./benchmarks/TokenBenchmark.sol";
import {BenchmarkDeployer} from "./benchmarks/BenchmarkDeployer.sol";

contract TokenCloneFactoryTest is Test {
    TokenCloneFactory public factory;
    address public owner;
    address public admin1;
    address public admin2;

    event TokenCreated(address indexed token, address indexed admin, string name, string symbol, uint8 decimals);

    function setUp() public {
        owner = makeAddr("owner");
        admin1 = makeAddr("admin1");
        admin2 = makeAddr("admin2");

        vm.prank(owner);
        factory = new TokenCloneFactory(owner);
    }

    function test_Deployment() public view {
        assertNotEq(address(factory.implementation()), address(0));
        assertEq(factory.owner(), owner);
    }

    function test_CreateToken() public {
        string memory name = "Security Token";
        string memory symbol = "SEC";
        uint8 decimals = 18;

        vm.expectEmit(false, true, false, true);
        emit TokenCreated(address(0), admin1, name, symbol, decimals);

        address tokenAddress = factory.createToken(name, symbol, decimals, admin1);

        assertNotEq(tokenAddress, address(0));
        assertNotEq(tokenAddress, factory.implementation());

        TokenCloneable token = TokenCloneable(tokenAddress);
        assertEq(token.name(), name);
        assertEq(token.symbol(), symbol);
        assertEq(token.decimals(), decimals);
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), admin1));
        assertTrue(token.hasRole(token.AGENT_ROLE(), admin1));
        assertTrue(token.hasRole(token.COMPLIANCE_ROLE(), admin1));
    }

    function test_CreateMultipleTokens() public {
        address token1 = factory.createToken("Token 1", "TK1", 18, admin1);
        address token2 = factory.createToken("Token 2", "TK2", 6, admin2);
        address token3 = factory.createToken("Token 3", "TK3", 18, admin1);

        assertNotEq(token1, token2);
        assertNotEq(token1, token3);
        assertNotEq(token2, token3);

        assertEq(factory.getTotalTokens(), 3);
        assertEq(factory.getTokenAt(0), token1);
        assertEq(factory.getTokenAt(1), token2);
        assertEq(factory.getTokenAt(2), token3);
    }

    function test_GetTokensByAdmin() public {
        address token1 = factory.createToken("Token 1", "TK1", 18, admin1);
        address token2 = factory.createToken("Token 2", "TK2", 6, admin2);
        address token3 = factory.createToken("Token 3", "TK3", 18, admin1);

        address[] memory admin1Tokens = factory.getTokensByAdmin(admin1);
        assertEq(admin1Tokens.length, 2);
        assertEq(admin1Tokens[0], token1);
        assertEq(admin1Tokens[1], token3);

        address[] memory admin2Tokens = factory.getTokensByAdmin(admin2);
        assertEq(admin2Tokens.length, 1);
        assertEq(admin2Tokens[0], token2);
    }

    function test_CreateTokenWithRegistries() public {
        address identityRegistry = makeAddr("identityRegistry");
        address trustedIssuersRegistry = makeAddr("trustedIssuersRegistry");
        address claimTopicsRegistry = makeAddr("claimTopicsRegistry");

        address tokenAddress = factory.createTokenWithRegistries(
            "Security Token", "SEC", 18, admin1, identityRegistry, trustedIssuersRegistry, claimTopicsRegistry
        );

        TokenCloneable token = TokenCloneable(tokenAddress);
        assertEq(address(token.identityRegistry()), identityRegistry);
        assertEq(address(token.trustedIssuersRegistry()), trustedIssuersRegistry);
        assertEq(address(token.claimTopicsRegistry()), claimTopicsRegistry);

        // Verify admin has all roles and factory doesn't
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), admin1));
        assertTrue(token.hasRole(token.AGENT_ROLE(), admin1));
        assertTrue(token.hasRole(token.COMPLIANCE_ROLE(), admin1));
        assertFalse(token.hasRole(token.DEFAULT_ADMIN_ROLE(), address(factory)));
        assertFalse(token.hasRole(token.AGENT_ROLE(), address(factory)));
        assertFalse(token.hasRole(token.COMPLIANCE_ROLE(), address(factory)));
    }

    function test_RevertWhenInvalidAdmin() public {
        vm.expectRevert("Invalid admin address");
        factory.createToken("Token", "TK", 18, address(0));
    }

    function test_RevertWhenEmptyName() public {
        vm.expectRevert("Token name required");
        factory.createToken("", "TK", 18, admin1);
    }

    function test_RevertWhenEmptySymbol() public {
        vm.expectRevert("Token symbol required");
        factory.createToken("Token", "", 18, admin1);
    }

    function test_RevertWhenInvalidIndex() public {
        vm.expectRevert("Index out of bounds");
        factory.getTokenAt(0);

        factory.createToken("Token", "TK", 18, admin1);

        vm.expectRevert("Index out of bounds");
        factory.getTokenAt(1);
    }

    function test_GasSavings() public {
        // Comparación EQUIVALENTE (H-03 / B-7): "clon EIP-1167 + initialize" (trabajo
        // real de createToken) contra "despliegue completo + inicialización equivalente"
        // (TokenBenchmark: ERC20 + AccessControl + Pausable con los mismos roles).
        // La implementación ya está desplegada en el constructor de la factory, igual
        // que en producción, así que solo se mide el coste marginal por token.
        uint256 gasBefore = gasleft();
        address clonedToken = factory.createToken("Clone Token", "CLN", 18, admin1);
        uint256 cloneGas = gasBefore - gasleft();

        gasBefore = gasleft();
        address baseline = BenchmarkDeployer.deployTokenBenchmark("Clone Token", "CLN", 18, admin1);
        uint256 fullDeployGas = gasBefore - gasleft();

        // La referencia hace el mismo trabajo de inicialización que el clon.
        assertEq(TokenBenchmark(baseline).name(), "Clone Token");
        assertTrue(TokenBenchmark(baseline).hasRole(TokenBenchmark(baseline).AGENT_ROLE(), admin1));
        assertEq(TokenCloneable(clonedToken).symbol(), "CLN");

        console.log("Clone (createToken) gas:", cloneGas);
        console.log("Full deployment + init gas:", fullDeployGas);

        uint256 saved = fullDeployGas - cloneGas;
        console.log("Gas saved:", saved);
        console.log("Savings percentage:", (saved * 100) / fullDeployGas);

        // Umbral documentado y realista (medido: ~55% de ahorro): >=45% sobre el
        // despliegue completo y un piso absoluto de 300k de gas para que la aserción
        // sea significativa. Los "94-98%" de los docs antiguos nunca estuvieron medidos.
        assertTrue(cloneGas < fullDeployGas, "Clone must be cheaper than full deployment");
        assertGe(saved * 100, fullDeployGas * 45, "Clone should save at least 45% gas");
        assertGt(saved, 300_000, "Absolute saving should exceed 300k gas");
    }

    function test_ClonedTokenFunctionality() public {
        address tokenAddress = factory.createToken("Test Token", "TEST", 18, admin1);
        TokenCloneable token = TokenCloneable(tokenAddress);

        // Test pausing
        vm.startPrank(admin1);
        token.pause();
        assertTrue(token.paused());
        token.unpause();
        assertFalse(token.paused());

        // Test freezing
        address user = makeAddr("user");
        token.freezeAccount(user);
        assertTrue(token.isFrozen(user));
        token.unfreezeAccount(user);
        assertFalse(token.isFrozen(user));

        vm.stopPrank();
    }

    function test_IndependentClones() public {
        address token1 = factory.createToken("Token 1", "TK1", 18, admin1);
        address token2 = factory.createToken("Token 2", "TK2", 6, admin2);

        TokenCloneable t1 = TokenCloneable(token1);
        TokenCloneable t2 = TokenCloneable(token2);

        // Pause token1
        vm.prank(admin1);
        t1.pause();

        // token1 is paused, token2 is not
        assertTrue(t1.paused());
        assertFalse(t2.paused());

        // Freeze account in token2
        address user = makeAddr("user");
        vm.prank(admin2);
        t2.freezeAccount(user);

        // user is frozen in token2 but not in token1
        assertFalse(t1.isFrozen(user));
        assertTrue(t2.isFrozen(user));
    }

    function test_GetGasSavingsInfo() public view {
        string memory info = factory.getGasSavingsInfo();
        assertTrue(bytes(info).length > 0);
    }

    // ===================== RF-005: implementacion y storage layout =====================

    /// @notice CU-08 EARS `test_RF005_initialization_implementacion_bloqueada`: la implementacion que
    /// expone la factory NO se puede inicializar. Su constructor ejecuta `_disableInitializers()`, de
    /// modo que un atacante que tome el `implementation()` no puede apropiarse de sus roles.
    function test_RF005_initialization_implementacion_bloqueada() public {
        TokenCloneable implementation = TokenCloneable(factory.implementation());

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        implementation.initialize("Token", "TK", 18, admin1);

        // La implementacion no tiene owner de roles: sigue sin admin tras el intento.
        assertFalse(implementation.hasRole(implementation.DEFAULT_ADMIN_ROLE(), admin1));
    }

    /// @notice CU-08 EARS `test_RF005_no_storage_muerto_tokenName`: `TokenCloneable` ya no declara
    /// `_tokenName`/`_tokenSymbol`. `name()`/`symbol()` los sirve `ERC20Upgradeable`; conservarlos era
    /// storage muerto (se escribian en `initialize` y nadie los leia). Se inspecciona el artefacto
    /// compilado, igual que `test_RF002_storage_layout_sin_bypassCompliance`.
    function test_RF005_no_storage_muerto_tokenName() public {
        string memory artifact =
            vm.readFile(string.concat(vm.projectRoot(), "/out/TokenCloneable.sol/TokenCloneable.json"));

        // Control positivo: el artefacto SI contiene el layout (y el decimal real que se usa).
        assertTrue(_contains(artifact, "identityRegistry"), "storageLayout ausente en el artefacto");
        assertTrue(_contains(artifact, "_tokenDecimals"), "_tokenDecimals debe seguir en el layout");

        // Control negativo: los dos slots muertos ya no existen.
        assertFalse(_contains(artifact, "_tokenName"), "_tokenName reaparecio en el storage layout");
        assertFalse(_contains(artifact, "_tokenSymbol"), "_tokenSymbol reaparecio en el storage layout");
    }

    function _contains(string memory haystack, string memory needle) internal pure returns (bool) {
        bytes memory h = bytes(haystack);
        bytes memory n = bytes(needle);
        if (n.length == 0) return true;
        if (n.length > h.length) return false;
        for (uint256 i = 0; i <= h.length - n.length; i++) {
            bool matched = true;
            for (uint256 j = 0; j < n.length; j++) {
                if (h[i + j] != n[j]) {
                    matched = false;
                    break;
                }
            }
            if (matched) return true;
        }
        return false;
    }
}

