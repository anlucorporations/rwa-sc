// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

interface IGovernanceMultisigConfig {
    function threshold() external view returns (uint256);
    function delay() external view returns (uint256);
    function ownerCount() external view returns (uint256);
}

/**
 * @title AdoptGovernance
 * @dev H-06 (R-7 / D-021): **adopción** de la gobernanza. Transfiere la propiedad (`Ownable`) de los
 *      contratos administrados al `GovernanceMultisig` y entrega los roles `AccessControl` del token
 *      (`DEFAULT_ADMIN_ROLE`, `AGENT_ROLE`, `COMPLIANCE_ROLE`) al multisig, renunciando la EOA a ellos.
 *
 *      No despliega nada: opera sobre el artefacto de despliegue canónico y el multisig ya desplegado
 *      (`script/DeployGovernance.s.sol`). Es idempotente en la parte de roles (grant repetido no falla)
 *      y falla en cerrado si alguna postcondición no se cumple.
 *
 * Variables de entorno:
 *   DEPLOYMENT_JSON               (obligatoria) ruta al artefacto de despliegue (p. ej. sc/deployments/<chain>-<ts>.json)
 *   GOVERNANCE_MULTISIG           (obligatoria) dirección de GovernanceMultisig
 *   ADOPT_SKIP_IDENTITY_REGISTRY  (opcional, 0|1; por defecto 0) si 1, NO transfiere IdentityRegistry
 *                                 (registro operativo de identidades: requiere decisión de producto)
 *   ALLOW_SHORT_DELAY             (opcional, 0|1; por defecto 0) permite delay < 24 h (solo drills locales)
 *
 * Uso (normalmente a través de `script/adopt_governance.sh`):
 *   forge script script/AdoptGovernance.s.sol:AdoptGovernance \
 *     --rpc-url "$RPC_URL" --broadcast --keystore <path> --password-file <path>
 */
contract AdoptGovernance is Script {
    bytes32 internal constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 internal constant AGENT_ROLE = keccak256("AGENT_ROLE");
    bytes32 internal constant COMPLIANCE_ROLE = keccak256("COMPLIANCE_ROLE");
    uint256 internal constant MIN_DELAY = 24 hours;

    struct Targets {
        address identityRegistry;
        address trustedIssuersRegistry;
        address tokenFactory;
        address identityFactory;
        address claimTopicsFactory;
        address aggregator;
        address claimTopicsRegistry;
        address token;
        address maxBalanceModule;
        address maxHoldersModule;
        address transferLockModule;
    }

    function run() external {
        address multisig = vm.envAddress("GOVERNANCE_MULTISIG");
        string memory jsonPath = vm.envString("DEPLOYMENT_JSON");
        bool skipIdentityRegistry = vm.envOr("ADOPT_SKIP_IDENTITY_REGISTRY", uint256(0)) == 1;
        bool allowShortDelay = vm.envOr("ALLOW_SHORT_DELAY", uint256(0)) == 1;

        string memory json = vm.readFile(jsonPath);
        Targets memory t = _loadTargets(json);
        address eoa = msg.sender;

        console.log("=== H-06: adopcion de la gobernanza (multisig + timelock) ===");
        console.log("EOA que entrega:", eoa);
        console.log("GovernanceMultisig:", multisig);
        console.log("Artefacto:", jsonPath);

        _preflight(multisig, eoa, skipIdentityRegistry, allowShortDelay);

        vm.startBroadcast();
        // 1) Roles del token (AccessControl) al multisig ...
        IAccessControl(t.token).grantRole(DEFAULT_ADMIN_ROLE, multisig);
        IAccessControl(t.token).grantRole(AGENT_ROLE, multisig);
        IAccessControl(t.token).grantRole(COMPLIANCE_ROLE, multisig);
        // 2) Propiedad (Ownable) de los contratos administrados al multisig ...
        _transferIfPresent("TrustedIssuersRegistry", t.trustedIssuersRegistry, multisig);
        _transferIfPresent("TokenCloneFactory", t.tokenFactory, multisig);
        _transferIfPresent("IdentityCloneFactory", t.identityFactory, multisig);
        _transferIfPresent("ClaimTopicsRegistryCloneFactory", t.claimTopicsFactory, multisig);
        _transferIfPresent("ComplianceAggregator", t.aggregator, multisig);
        _transferIfPresent("ClaimTopicsRegistry", t.claimTopicsRegistry, multisig);
        _transferIfPresent("MaxBalanceCompliance", t.maxBalanceModule, multisig);
        _transferIfPresent("MaxHoldersCompliance", t.maxHoldersModule, multisig);
        _transferIfPresent("TransferLockCompliance", t.transferLockModule, multisig);
        if (skipIdentityRegistry) {
            console.log("AVISO: se omite IdentityRegistry (ADOPT_SKIP_IDENTITY_REGISTRY=1)");
        } else {
            _transferIfPresent("IdentityRegistry", t.identityRegistry, multisig);
        }
        // 3) La EOA renuncia a sus roles del token (el multisig ya los tiene) ...
        IAccessControl(t.token).renounceRole(DEFAULT_ADMIN_ROLE, eoa);
        IAccessControl(t.token).renounceRole(AGENT_ROLE, eoa);
        IAccessControl(t.token).renounceRole(COMPLIANCE_ROLE, eoa);
        vm.stopBroadcast();

        _verify(t, multisig, eoa, skipIdentityRegistry);
        console.log("OK: gobernanza adoptada. La EOA ha perdido la administracion.");
    }

    // ---------------------------------------------------------------------------------------
    // Lectura del artefacto
    // ---------------------------------------------------------------------------------------

    function _loadTargets(string memory json) internal view returns (Targets memory t) {
        t.identityRegistry = vm.parseJsonAddress(json, ".contracts.IdentityRegistry");
        t.trustedIssuersRegistry = vm.parseJsonAddress(json, ".contracts.TrustedIssuersRegistry");
        t.tokenFactory = vm.parseJsonAddress(json, ".contracts.TokenCloneFactory");
        t.identityFactory = vm.parseJsonAddress(json, ".contracts.IdentityCloneFactory");
        t.claimTopicsFactory = vm.parseJsonAddress(json, ".contracts.ClaimTopicsRegistryCloneFactory");
        t.aggregator = vm.parseJsonAddress(json, ".contracts.ComplianceAggregator");
        t.claimTopicsRegistry = vm.parseJsonAddress(json, ".contracts.ClaimTopicsRegistry");
        t.token = vm.parseJsonAddress(json, ".token.address");
        t.maxBalanceModule = _parseAddressOrZero(json, ".compliance.MaxBalanceCompliance");
        t.maxHoldersModule = _parseAddressOrZero(json, ".compliance.MaxHoldersCompliance");
        t.transferLockModule = _parseAddressOrZero(json, ".compliance.TransferLockCompliance");
    }

    function _parseAddressOrZero(string memory json, string memory key) internal view returns (address) {
        bytes memory raw = vm.parseJson(json, key);
        if (raw.length == 0) return address(0);
        return abi.decode(raw, (address));
    }

    // ---------------------------------------------------------------------------------------
    // Preflight y adopción
    // ---------------------------------------------------------------------------------------

    function _preflight(address multisig, address eoa, bool skipIdentityRegistry, bool allowShortDelay) internal view {
        require(multisig != address(0), "GOVERNANCE_MULTISIG es la direccion cero");
        require(multisig != eoa, "el multisig no puede ser la propia EOA");
        require(multisig.code.length > 0, "GOVERNANCE_MULTISIG no tiene codigo");

        uint256 threshold = IGovernanceMultisigConfig(multisig).threshold();
        uint256 delay = IGovernanceMultisigConfig(multisig).delay();
        uint256 owners = IGovernanceMultisigConfig(multisig).ownerCount();
        require(threshold >= 2, "threshold < 2: la gobernanza no es M-de-N real");
        require(threshold <= owners, "threshold > numero de owners");
        require(owners >= 3, "se recomiendan >= 3 owners (D-021)");
        if (!allowShortDelay) {
            require(delay >= MIN_DELAY, "delay < 24h: use ALLOW_SHORT_DELAY=1 solo en drills locales");
        }
        console.log("Multisig owners:", owners);
        console.log("Multisig threshold:", threshold);
        console.log("Multisig delay (s):", delay);
        console.log("Omitir IdentityRegistry:", skipIdentityRegistry ? uint256(1) : uint256(0));
    }

    function _transferIfPresent(string memory name, address target, address newOwner) internal {
        if (target == address(0)) return;
        address current = Ownable(target).owner();
        if (current == newOwner) {
            console.log("  = %s ya pertenece al multisig", name);
            return;
        }
        require(current == msg.sender, string.concat("no soy owner de ", name));
        Ownable(target).transferOwnership(newOwner);
        console.log("  -> %s transferido al multisig", name);
    }

    // ---------------------------------------------------------------------------------------
    // Verificación en cerrado
    // ---------------------------------------------------------------------------------------

    function _verify(Targets memory t, address multisig, address eoa, bool skipIdentityRegistry) internal view {
        console.log("=== Verificacion de gobernanza ===");
        if (!skipIdentityRegistry) {
            require(Ownable(t.identityRegistry).owner() == multisig, "IdentityRegistry sin multisig");
        }
        require(Ownable(t.trustedIssuersRegistry).owner() == multisig, "TrustedIssuersRegistry sin multisig");
        require(Ownable(t.tokenFactory).owner() == multisig, "TokenCloneFactory sin multisig");
        require(Ownable(t.identityFactory).owner() == multisig, "IdentityCloneFactory sin multisig");
        require(Ownable(t.claimTopicsFactory).owner() == multisig, "ClaimTopicsRegistryCloneFactory sin multisig");
        require(Ownable(t.aggregator).owner() == multisig, "ComplianceAggregator sin multisig");
        require(Ownable(t.claimTopicsRegistry).owner() == multisig, "ClaimTopicsRegistry sin multisig");
        if (t.maxBalanceModule != address(0)) {
            require(Ownable(t.maxBalanceModule).owner() == multisig, "MaxBalanceCompliance sin multisig");
        }
        if (t.maxHoldersModule != address(0)) {
            require(Ownable(t.maxHoldersModule).owner() == multisig, "MaxHoldersCompliance sin multisig");
        }
        if (t.transferLockModule != address(0)) {
            require(Ownable(t.transferLockModule).owner() == multisig, "TransferLockCompliance sin multisig");
        }

        IAccessControl token = IAccessControl(t.token);
        require(token.hasRole(DEFAULT_ADMIN_ROLE, multisig), "token: multisig sin DEFAULT_ADMIN_ROLE");
        require(token.hasRole(AGENT_ROLE, multisig), "token: multisig sin AGENT_ROLE");
        require(token.hasRole(COMPLIANCE_ROLE, multisig), "token: multisig sin COMPLIANCE_ROLE");
        require(!token.hasRole(DEFAULT_ADMIN_ROLE, eoa), "token: la EOA conserva DEFAULT_ADMIN_ROLE");
        require(!token.hasRole(AGENT_ROLE, eoa), "token: la EOA conserva AGENT_ROLE");
        require(!token.hasRole(COMPLIANCE_ROLE, eoa), "token: la EOA conserva COMPLIANCE_ROLE");
    }
}
