// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {TokenCloneable} from "../../../src/TokenCloneable.sol";
import {IdentityCloneable} from "../../../src/IdentityCloneable.sol";
import {TrustedIssuersRegistry} from "../../../src/TrustedIssuersRegistry.sol";
import {ClaimTopicsRegistry} from "../../../src/ClaimTopicsRegistry.sol";
import {SigUtils} from "../../helpers/SigUtils.sol";
import {BaseHandler} from "./BaseHandler.sol";

/**
 * @title TokenGhosts
 * @notice Estado fantasma escrito por `TokenHandler` y leido por los invariantes.
 *
 * Los "call properties" (p. ej. "burn nunca supera maxBurnPerTx") no se pueden expresar como
 * una propiedad de estado pura: hay que observar el estado **en el momento de la llamada**. El
 * handler registra aqui si alguna llamada con exito violo la propiedad; los invariantes solo
 * comprueban que ningun flag esta activo. Se usan flags (y no `assert` dentro del handler)
 * porque `[invariant] fail_on_revert = false` descarta los reverts del handler, incluidos los
 * de `assert`.
 */
contract TokenGhosts {
    bool public burnLimitViolated;
    bool public forcedDestViolated;
    bool public forcedLimitViolated;
    bool public frozenTransferViolated;
    bool public pausedTransferViolated;
    bool public supplyDecreasedWithoutBurn;

    /// @dev Contador de acciones con exito, para evidenciar que el handler ejercita caminos
    /// reales y no solo secuencias de reverts.
    mapping(bytes32 => uint256) public successCount;

    function record(bytes32 action) external {
        successCount[action]++;
    }

    function markBurnLimitViolation() external {
        burnLimitViolated = true;
    }

    function markForcedDestViolation() external {
        forcedDestViolated = true;
    }

    function markForcedLimitViolation() external {
        forcedLimitViolated = true;
    }

    function markFrozenTransferViolation() external {
        frozenTransferViolated = true;
    }

    function markPausedTransferViolation() external {
        pausedTransferViolated = true;
    }

    function markSupplyDecreasedWithoutBurn() external {
        supplyDecreasedWithoutBurn = true;
    }
}

/**
 * @title TokenHandler
 * @notice Handler con estado para los invariantes de `TokenCloneable` (RF-009 / Fase 4).
 *
 * Acciones acotadas: todos los destinos, cuentas y emisores se eligen de pools fijos y los
 * importes se acotan. El handler **no revierte** (los fallos de las llamadas se ignoran); las
 * violaciones de propiedades de llamada se anotan en `TokenGhosts`.
 *
 * El handler recibe los roles del token (`DEFAULT_ADMIN_ROLE`, `AGENT_ROLE`, `COMPLIANCE_ROLE`)
 * y es `owner` de `TrustedIssuersRegistry`/`ClaimTopicsRegistry` para poder mutar la politica
 * de claims. Las identidades siguen siendo del contrato de test (`identityOwner`), por lo que
 * el alta/baja de claims se hace con `vm.prank(identityOwner)`.
 */
contract TokenHandler is BaseHandler {
    /// @dev Configuracion agrupada en un struct: un constructor con 12 parametros sueltos
    /// agota la pila del compilador con `solc 0.8.20` + optimizer 200 (sin `viaIR`).
    struct Config {
        TokenCloneable token;
        TrustedIssuersRegistry issuers;
        ClaimTopicsRegistry topics;
        TokenGhosts ghosts;
        address identityOwner;
        address issuer;
        uint256 issuerPk;
        uint256 kycTopic;
        uint256 amlTopic;
    }

    TokenCloneable private token;
    TrustedIssuersRegistry private issuers;
    ClaimTopicsRegistry private topics;
    TokenGhosts private ghosts;
    address private identityOwner;
    address private issuer;
    uint256 private issuerPk;
    uint256 private kycTopic;
    uint256 private amlTopic;
    address[] private actors;
    IdentityCloneable[] private identities;
    address[] private modules;

    constructor(
        Config memory config,
        address[] memory _actors,
        IdentityCloneable[] memory _identities,
        address[] memory _modules
    ) {
        token = config.token;
        issuers = config.issuers;
        topics = config.topics;
        ghosts = config.ghosts;
        identityOwner = config.identityOwner;
        actors = _actors;
        identities = _identities;
        issuer = config.issuer;
        issuerPk = config.issuerPk;
        kycTopic = config.kycTopic;
        amlTopic = config.amlTopic;
        modules = _modules;
    }

    // ============ Token: emision y quema ============

    function mint(uint256 actorSeed, uint256 amount) external {
        address to = actors[actorSeed % actors.length];
        amount = _bound(amount, 0, 1_000e18);
        uint256 supplyBefore = token.totalSupply();
        bool ok = _call(address(token), abi.encodeCall(TokenCloneable.mint, (to, amount)));
        if (ok) {
            ghosts.record("mint");
        }
        _checkSupplyNotDecreased(supplyBefore);
    }

    function burn(uint256 actorSeed, uint256 amount) external {
        address from = actors[actorSeed % actors.length];
        amount = _bound(amount, 0, 1_000e18);
        uint256 limitBefore = token.maxBurnPerTx();
        bool ok = _call(address(token), abi.encodeCall(TokenCloneable.burn, (from, amount)));
        if (ok) {
            ghosts.record("burn");
            if (!(limitBefore > 0 && amount <= limitBefore)) {
                ghosts.markBurnLimitViolation();
            }
        }
    }

    // ============ Token: transferencias ============

    function transfer(uint256 fromSeed, uint256 toSeed, uint256 amount) external {
        address from = actors[fromSeed % actors.length];
        address to = actors[toSeed % actors.length];
        amount = _bound(amount, 0, 500e18);

        bool wasPaused = token.paused();
        bool wasFrozenFrom = token.isFrozen(from);
        bool wasFrozenTo = token.isFrozen(to);
        uint256 supplyBefore = token.totalSupply();

        vm.prank(from);
        bool ok = _call(address(token), abi.encodeCall(TokenCloneable.transfer, (to, amount)));

        if (ok) {
            ghosts.record("transfer");
            if (wasPaused) ghosts.markPausedTransferViolation();
            if (wasFrozenFrom || wasFrozenTo) ghosts.markFrozenTransferViolation();
        }
        _checkSupplyNotDecreased(supplyBefore);
    }

    function transferFrom(uint256 fromSeed, uint256 toSeed, uint256 amount) external {
        address from = actors[fromSeed % actors.length];
        address to = actors[toSeed % actors.length];
        amount = _bound(amount, 0, 500e18);

        bool wasPaused = token.paused();
        bool wasFrozenFrom = token.isFrozen(from);
        bool wasFrozenTo = token.isFrozen(to);
        uint256 supplyBefore = token.totalSupply();

        bool ok = _call(address(token), abi.encodeCall(TokenCloneable.transferFrom, (from, to, amount)));

        if (ok) {
            ghosts.record("transferFrom");
            if (wasPaused) ghosts.markPausedTransferViolation();
            if (wasFrozenFrom || wasFrozenTo) ghosts.markFrozenTransferViolation();
        }
        _checkSupplyNotDecreased(supplyBefore);
    }

    function forcedTransfer(uint256 fromSeed, uint256 toSeed, uint256 amount) external {
        address from = actors[fromSeed % actors.length];
        address to = actors[toSeed % actors.length];
        amount = _bound(amount, 0, 1_000e18);

        bool authorizedBefore = token.authorizedDestinations(to);
        uint256 limitBefore = token.maxForcedPerTx();
        uint256 supplyBefore = token.totalSupply();

        bool ok = _call(address(token), abi.encodeCall(TokenCloneable.forcedTransfer, (from, to, amount)));

        if (ok) {
            ghosts.record("forcedTransfer");
            if (!authorizedBefore) ghosts.markForcedDestViolation();
            if (!(limitBefore > 0 && amount <= limitBefore)) ghosts.markForcedLimitViolation();
        }
        _checkSupplyNotDecreased(supplyBefore);
    }

    // ============ Token: administracion ============

    function freezeAccount(uint256 actorSeed) external {
        address account = actors[actorSeed % actors.length];
        _call(address(token), abi.encodeCall(TokenCloneable.freezeAccount, (account)));
    }

    function unfreezeAccount(uint256 actorSeed) external {
        address account = actors[actorSeed % actors.length];
        _call(address(token), abi.encodeCall(TokenCloneable.unfreezeAccount, (account)));
    }

    function pause() external {
        _call(address(token), abi.encodeCall(TokenCloneable.pause, ()));
    }

    function unpause() external {
        _call(address(token), abi.encodeCall(TokenCloneable.unpause, ()));
    }

    function setAuthorizedDestination(uint256 actorSeed, bool authorized) external {
        address destination = actors[actorSeed % actors.length];
        _call(address(token), abi.encodeCall(TokenCloneable.setAuthorizedDestination, (destination, authorized)));
    }

    function setMaxBurnPerTx(uint256 value) external {
        value = _bound(value, 0, 2_000e18);
        _call(address(token), abi.encodeCall(TokenCloneable.setMaxBurnPerTx, (value)));
    }

    function setMaxForcedPerTx(uint256 value) external {
        value = _bound(value, 0, 2_000e18);
        _call(address(token), abi.encodeCall(TokenCloneable.setMaxForcedPerTx, (value)));
    }

    function setMaxSupply(uint256 value) external {
        // Cubre los tres casos: sin tope (0), tope por encima del suministro y tope invalido
        // (por debajo del suministro, que debe revertir y quedar ignorado).
        uint256 supply = token.totalSupply();
        if (value % 3 == 0) {
            value = 0;
        } else if (value % 3 == 1) {
            value = _bound(value, supply, supply + 1_000e18);
        } else {
            value = supply == 0 ? 0 : _bound(value, 0, supply - 1);
        }
        _call(address(token), abi.encodeCall(TokenCloneable.setMaxSupply, (value)));
    }

    function addComplianceModule(uint256 seed) external {
        address module = modules[seed % modules.length];
        _call(address(token), abi.encodeCall(TokenCloneable.addComplianceModule, (module)));
    }

    function removeComplianceModule(uint256 seed) external {
        uint256 count = token.getComplianceModules().length;
        if (count == 0) {
            return;
        }
        _call(address(token), abi.encodeCall(TokenCloneable.removeComplianceModule, (seed % count)));
    }

    // ============ Politica de claims (issuers y topics) ============

    function addTrustedIssuer() external {
        uint256[] memory issuerTopics = new uint256[](2);
        issuerTopics[0] = kycTopic;
        issuerTopics[1] = amlTopic;
        _call(address(issuers), abi.encodeCall(TrustedIssuersRegistry.addTrustedIssuer, (issuer, issuerTopics)));
    }

    function removeTrustedIssuer() external {
        _call(address(issuers), abi.encodeCall(TrustedIssuersRegistry.removeTrustedIssuer, (issuer)));
    }

    function addClaimTopic(uint256 seed) external {
        uint256 topic = _bound(seed, 1, 3);
        _call(address(topics), abi.encodeCall(ClaimTopicsRegistry.addClaimTopic, (topic)));
    }

    function removeClaimTopic(uint256 seed) external {
        uint256 topic = _bound(seed, 1, 3);
        _call(address(topics), abi.encodeCall(ClaimTopicsRegistry.removeClaimTopic, (topic)));
    }

    // ============ Claims de las identidades ============

    function revokeClaim(uint256 actorSeed, uint256 topicSeed) external {
        IdentityCloneable identity = identities[actorSeed % identities.length];
        uint256 topic = topicSeed % 2 == 0 ? kycTopic : amlTopic;
        vm.prank(issuer);
        _call(address(identity), abi.encodeCall(IdentityCloneable.revokeClaim, (topic, issuer)));
    }

    function renewClaim(uint256 actorSeed, uint256 topicSeed, uint256 expiresAt) external {
        IdentityCloneable identity = identities[actorSeed % identities.length];
        uint256 topic = topicSeed % 2 == 0 ? kycTopic : amlTopic;
        // D-038: solo se usan valores 0 (sin caducidad) o marcas futuras/vencidas acotadas.
        expiresAt = expiresAt % 4 == 0 ? 0 : _bound(expiresAt, 1, 4_000_000_000);

        bytes memory data = abi.encode(topic, address(identity));
        uint256 nonce = identity.claimNonce(topic, issuer);
        bytes memory signature =
            SigUtils.signClaim(issuerPk, address(identity), identityOwner, topic, 1, data, expiresAt, nonce);

        vm.prank(identityOwner);
        _call(
            address(identity),
            abi.encodeCall(IdentityCloneable.addClaim, (topic, 1, issuer, signature, data, "", expiresAt))
        );
    }

    function removeClaim(uint256 actorSeed, uint256 topicSeed) external {
        IdentityCloneable identity = identities[actorSeed % identities.length];
        uint256 topic = topicSeed % 2 == 0 ? kycTopic : amlTopic;
        vm.prank(identityOwner);
        _call(address(identity), abi.encodeCall(IdentityCloneable.removeClaim, (topic, issuer)));
    }

    /// @dev Avanza el reloj (solo hacia delante) para alcanzar/rebasar `expiresAt` de los claims.
    function warpTime(uint256 secondsForward) external {
        vm.warp(block.timestamp + _bound(secondsForward, 0, 365 days));
    }

    /// @dev `totalSupply` solo puede bajar por `burn`; cualquier otra accion que lo reduzca es una
    /// violacion (p. ej. una transferencia que alterase la contabilidad).
    function _checkSupplyNotDecreased(uint256 supplyBefore) private {
        if (token.totalSupply() < supplyBefore) {
            ghosts.markSupplyDecreasedWithoutBurn();
        }
    }
}
