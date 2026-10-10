# Auditoría final adversarial — Fase 4 (Pruebas) · contratos RWA `rwa-sc`

> **Rol:** auditor de seguridad adversarial externo (revisión de solo lectura).
> **Fecha:** 2026-10-11 · **Alcance:** `rwa-sc/sc/src/**` (15 contratos), `rwa-sc/sc/script/**`, `rwa-sc/.gitlab-ci.yml`, `rwa-sc/sc/test/**`, `SECURITY.md`, `CHANGELOG_ABIS.md`, `RepoTecnico/**`.
> **Método:** revisión manual cruzada de interacciones + ejecución del toolchain fijado (`forge 1.8.3`, solc 0.8.20) para verificar la línea base.
> **Regla aplicada:** ante la duda, se descarta y se declara (ver §5).

---

## 1. Veredicto

| Pregunta | Respuesta |
|---|---|
| ¿Apto para **continuar a manuales / entrega interna**? | **SÍ, con reservas acotadas.** No hay hallazgos CRÍTICOS nuevos. Los 368 tests pasan (22 suites, 19 invariantes) y los 5 gates de `ci-checks` + `fmt` pasan en el toolchain fijado. Las reservas son AF-01, AF-02, AF-06 y AF-07: no bloquean la redacción de manuales, pero deben entrar en el plan de cierre de Fase 4 (§7). |
| ¿Apto para **producción con activos reales**? | **NO.** Conforme a **D-024** (`RepoTecnico/requerimientos.md:143-144`), la auditoría externa y la gobernanza objetivo (multisig/timelock, D-021) son bloqueantes solo para producción; además persisten H-11 (PII), H-12/H-21 (observabilidad), H-19 (estado singleton de módulos), H-20 (arrays O(n)) y la falta de runbook de migración (AF-10). |

**Matiz D-024 (textual):** *"la auditoría externa (R-9/H-16) es bloqueante solo para producción con activos reales, no para cerrar RF-001..RF-013"*. Este informe es una revisión adversarial de Fase 4, **no** sustituye a R-9; no se ha auditado criptografía propia nueva (la EIP-712 se reproduce con `ECDSA` de OpenZeppelin, D-026), pero **sí** se ha verificado el digest y sus coberturas.

---

## 2. Metodología y qué se leyó

**Leído línea a línea (lectura):**

- Código: `sc/src/TokenCloneable.sol`, `IdentityCloneable.sol`, `IdentityRegistry.sol`, `TrustedIssuersRegistry.sol`, `ClaimTopicsRegistry.sol`, `ClaimTopicsRegistryCloneable.sol`, `ClaimTopicsRegistryCloneFactory.sol`, `TokenCloneFactory.sol`, `IdentityCloneFactory.sol`, `ICompliance.sol`, `IClaimTopicsRegistry.sol`, `compliance/ComplianceAggregator.sol`, `compliance/MaxBalanceCompliance.sol`, `compliance/MaxHoldersCompliance.sol`, `compliance/TransferLockCompliance.sol`.
- Scripts: `DeployFullStack.s.sol`, `DeployComplianceAggregator.s.sol`, `CompleteDeploymentExample.s.sol`, `CreateTokenWithCloneFactory.s.sol`, `Deploy*Factory.s.sol`, `deploy.sh`, `deploy-besu.sh`, `script/ci/*.sh`.
- Pruebas: las 22 suites (incluidas `test/invariant/**` y sus handlers) y `test/helpers/SigUtils.sol`.
- Documentación: `SECURITY.md`, `CHANGELOG_ABIS.md`, `RepoTecnico/INFORME_OPTIMIZACION_V1.md`, `RepoTecnico/requerimientos.md` (RF/RNF/D-001..D-074), `RepoTecnico/documento_tecnico.md`, `RepoTecnico/pruebas/matriz_criterios.md`, `RepoTecnico/entornos_globales.md`, `RepoTecnico/estado_proyecto.md`, `casos_uso/casos_uso.md`.

**Verificado por ejecución (evidencia objetiva):**

- `forge test` → **368 tests passed, 0 failed, 0 skipped** en 22 suites (incluye 19 `invariant_*`).
- `forge fmt --check` → OK.
- `bash script/ci/check_no_bypass_flag.sh` → OK (el storage layout de `TokenCloneable` no contiene `bypassCompliance`).
- `bash script/ci/abi_diff.sh` → OK (15 ABIs sin deriva respecto a `sc/abis/`).
- `bash script/ci/check_docs.sh` → OK (12 documentos).
- `bash script/ci/check_secrets.sh` → OK (99 archivos versionados, 9 scripts/config).
- Rama activa: `rwa-sc-DSH-GCP`; árbol de trabajo limpio.

**Ejes de búsqueda (según encargo):** interacciones EIP-712+nonce / vigencia/revocación / fail-closed `isVerified` / whitelist+topes+`maxSupply` / retirada del flag de bypass+`nonReentrant` / ERC-165 / aggregator fail-closed y gestión por token; control de acceso y gobernanza; supuestos off-chain; estado y escalabilidad; residuos de los 14 ciclos; comportamiento ante fallo de módulo/registry/migración.

---

## 3. Tabla de hallazgos

| ID | Sev. | Área | Título | Evidencia |
|---|---|---|---|---|
| AF-01 | **ALTA** | Compliance / integración | Un módulo mal configurado o que revierte bloquea **todo** el token (sin validación de configuración en el alta ni aislamiento de revert) | `sc/src/TokenCloneable.sol:151-157`, `:277-279`, `:434-438`, `:484-489`; `sc/src/compliance/MaxBalanceCompliance.sol:60-72`, `:77-79`; `sc/src/compliance/MaxHoldersCompliance.sol:138-146` |
| AF-02 | MEDIA | Pausa/congelación × operaciones privilegiadas | `mint`/`burn`/`forcedTransfer` no respetan `paused()` ni `frozen`; `mint` a cuenta congelada se permite y la transferencia normal a esa misma cuenta revierte | `TokenCloneable.sol:268-274`, `:294-303`, `:319-332` vs `:417-441`; `casos_uso/casos_uso.md:640-646`; `test/invariant/handlers/TokenHandler.sol:157-168`, `:178-189` |
| AF-03 | MEDIA | EIP-712 / RF-001 | El digest firmado **no cubre `_uri`**; el titular puede fijar/alterar el URI del claim sin nueva firma del issuer | `IdentityCloneable.sol:62-64`, `:39-51`, `:156-167`; `CHANGELOG_ABIS.md:290-296` |
| AF-04 | MEDIA | Supuestos off-chain / factory | `createIdentityWithClaim` firma `walletOwner = factory`: el vínculo con el titular es solo la dirección del clon (predecible) → front-running consume la firma y la del titular revierte | `IdentityCloneFactory.sol:80-112`; `IdentityCloneable.sol:152-167`; `requerimientos.md:164-170` (D-027) |
| AF-05 | MEDIA | Compliance fail-closed | El fail-closed de RF-012 no se extiende al array del token: con `complianceModules.length == 0` `canTransfer` devuelve `true` (retirar el aggregator desactiva toda regla) | `TokenCloneable.sol:434-440`, `:185-191`; `ComplianceAggregator.sol:155-159`; `test/RF012_AggregatorFailClosed.t.sol:270` |
| AF-06 | MEDIA | Trazabilidad Fase 4 | `matriz_criterios.md` está desactualizada: declara 9 FALTA y "18 archivos/353 tests" cuando al menos 8 FALTA ya están cubiertos | `RepoTecnico/pruebas/matriz_criterios.md:16,23-28,204-230,257` vs `test/RF012_AggregatorFailClosed.t.sol:270`, `test/RF011_FailClosed.t.sol:158,178`, `test/TokenReentrancy.t.sol:372`, `test/TokenCloneFactory.t.sol:226,237`, `script/ci/check_secrets.sh` |
| AF-07 | MEDIA | Despliegue / post-deploy | El despliegue canónico deja el token **inoperable** (identidad sin claim, sin límites) y la verificación on-chain aun así termina en verde: no hay smoke test de emisión/transferencia | `DeployFullStack.s.sol:112-113`, `:60-61`; `script/deploy.sh:220-297` |
| AF-08 | MEDIA | Scripts | `CompleteDeploymentExample.s.sol` está roto desde RF-001 (firma `hex""` en `addClaim` revierte) y aún se anuncia como "Ejemplo completo" | `CompleteDeploymentExample.s.sol:158-175`, `:196-197`; `README.md:129`; `CLAIM_TOPICS_REGISTRY_FACTORY.md:219` |
| AF-09 | MEDIA | Scripts / ABI | `DeployComplianceAggregator.s.sol` imprime como "Next Steps" una llamada inexistente: `aggregator.configureToken(...)` | `script/DeployComplianceAggregator.s.sol:34` vs `compliance/ComplianceAggregator.sol:97-116` |
| AF-10 | MEDIA | Ciclo de vida (D-019) | Falta el **runbook de migración** exigido por D-019: solo hay menciones del requisito, ningún artefacto operativo | `RepoTecnico/requerimientos.md:129-130`; `documento_tecnico.md:270,775,789` |
| AF-11 | MEDIA | Deriva documental / CI | `SECURITY.md` afirma que RF-009/`.gitlab-ci.yml` "sigue pendiente", y `.gitlab-ci.yml` dice que "aún no ha corrido en remoto", contradiciendo `estado_proyecto.md:51,137,255` | `SECURITY.md:45,163-164`; `.gitlab-ci.yml:16-18`; `RepoTecnico/estado_proyecto.md:51,137,255` |
| AF-12 | BAJA | RF-013 | `removeClaim` (titular) borra un claim revocado (pierde la traza que D-046 dice conservar), no incrementa el `nonce` y deja al issuer sin poder revocar | `IdentityCloneable.sol:205-223`, `:241-243`; `requerimientos.md:289-294` (D-046) |
| AF-13 | BAJA | Aggregator | `removeModuleThroughAggregator` no comprueba que el aggregator sea módulo registrado del token (asimetría con `add`) | `TokenCloneable.sol:510-526` vs `:533-539` |
| AF-14 | BAJA | CI / secretos | `check_secrets.sh` define `DOC_RE` y no lo usa; los `.md` quedan fuera del escaneo de claves crudas, así que una clave pegada en documentación pasa el gate | `script/ci/check_secrets.sh:48-51`, `:63`, `:78-85` |
| AF-15 | BAJA | Deriva documental | `requerimientos.md:133` (D-020) mantiene el `CLAIM_TYPEHASH` sin `nonce` (superado por D-050); `:120` (D-016) cita `TokenCloneable.sol:180-182` cuando el chequeo está en `:277-279` | `RepoTecnico/requerimientos.md:120,133,311-317`; `documento_tecnico.md:776` |

**Recuento:** 1 ALTA · 10 MEDIA · 4 BAJA · 0 CRÍTICA.

---

## 4. Detalle de los hallazgos ALTA y MEDIA

### AF-01 · ALTA — Un módulo de compliance mal configurado o que revierte bloquea todo el token

**Qué ocurre.** El alta de un módulo solo valida que declare ERC-165; **no** valida que esté configurado para *este* token. Los módulos `MaxBalanceCompliance` y `MaxHoldersCompliance` obtienen el saldo con `staticcall` y decodifican la respuesta **sin comprobar la longitud**:

- `MaxBalanceCompliance.canTransfer` (`sc/src/compliance/MaxBalanceCompliance.sol:60-72`): si `tokenContract` no se ha fijado (`address(0)`) o apunta a una cuenta sin código, `staticcall` devuelve `success == true` con retorno vacío; `abi.decode(data, (uint256))` **revierte** (no devuelve `false`).
- `MaxHoldersCompliance.transferred` (`MaxHoldersCompliance.sol:138-146`) tiene el mismo patrón.
- El bucle del token (`TokenCloneable.sol:434-438` en `canTransfer`; `:277-279` en `mint`; `:484-489` en `_update`) **no aísla el revert**: la excepción propaga y **toda** transferencia/emisión revierte con un error opaco.
- Contraste: el token sí comprueba longitud en `_implementsCompliance` (`TokenCloneable.sol:176-180`) y en `isVerified` (`:399`), es decir, el patrón seguro ya existe en el propio repo.

**Impacto real.** Un error de operación plausible (desplegar el módulo y registrarlo sin `setTokenContract`, o reutilizarlo vía aggregator para un token nuevo sin reapuntarlo) deja el token **inoperable** hasta que `COMPLIANCE_ROLE` retire el módulo. Además, si `tokenContract` apunta a **otro** token, la regla de saldo se evalúa contra el saldo equivocado. Es la peor cara de la interacción "ERC-165 válido ≠ módulo utilizable".

**Recomendación acotada.**
1. En `TokenCloneable.addComplianceModule`, además de ERC-165, hacer un `staticcall` de verificación de configuración cuando el módulo exponga `tokenContract()` (o al menos documentar el orden obligatorio y añadirlo al despliegue).
2. Sustituir `abi.decode` directo por el patrón ya usado en `_implementsCompliance`: `success && data.length >= 32` antes de decodificar (degradar a `false`, no revertir).
3. Envolver los bucles de notificación en un helper que, ante revert de un módulo, revierta con un motivo explícito (o degrade a fail-closed), y añadir test de "módulo sin `tokenContract` no bloquea el token".

---

### AF-02 · MEDIA — Pausa y congelación no cubren `mint`/`burn`/`forcedTransfer`

**Qué ocurre.** `pause()` y `frozen[]` se aplican **solo** en `canTransfer` (`TokenCloneable.sol:417-441`), que es invocado exclusivamente para transferencias reales (`_update`, `:478`). Las tres operaciones privilegiadas no lo llaman:

- `mint` (`:268-274`): exige `isVerified(to)` y `maxSupply`, y consulta a los módulos, pero **no** comprueba `paused()` ni `frozen[to]`.
- `burn` (`:294-303`) y `forcedTransfer` (`:319-332`): tampoco comprueban `paused()`/`frozen`.

**Impacto real.** Inconsistencia observable: una transferencia normal a una cuenta congelada revierte (`"Transfer not compliant"`), pero `AGENT_ROLE` puede **acuñar** a esa misma cuenta congelada; y durante una pausa de emergencia el agente puede seguir emitiendo y moviendo saldos por `forcedTransfer` hacia destinos autorizados. La documentación de casos de uso solo enuncia pausa/congelación para `transfer` (`casos_uso.md:640-646`, A10.1/A10.2) y la suite de invariantes solo marca violación en `transfer`/`transferFrom` (`TokenHandler.sol:157-168`, `:178-189`): **no hay test que fije la semántica**.

**Recomendación acotada.** Decidir explícitamente y materializar: si la pausa es un control de emergencia total, añadir `whenNotPaused` a `mint` (y a `forcedTransfer`), y `require(!frozen[to])` en `mint`; si `burn`/`forcedTransfer` deben seguir operativos durante la pausa (recuperación), documentarlo en `casos_uso.md` y cubrirlo con un test.

---

### AF-03 · MEDIA — El digest EIP-712 no cubre `_uri`

**Qué ocurre.** El `CLAIM_TYPEHASH` vigente es `Claim(walletOwner,topic,scheme,dataHash,expiresAt,nonce)` (`IdentityCloneable.sol:62-64`) y el `structHash` se construye en `:156-167`. El campo `uri` del struct `Claim` (`:47-50`) se **almacena y se emite** (`ClaimAdded`, `:76-84`) pero **no entra en el digest**. `addClaim` es `onlyOwner` del clon.

**Impacto real.** El owner de la identidad (el titular) puede añadir/renovar un claim usando una firma legítima con **cualquier `uri`**, o volver a llamar `addClaim` con la misma firma y otro `uri` sin consentimiento del issuer. La verificación (`hasValidClaim`, `:305-318`) no usa `uri`, así que **no hay bypass de compliance**, pero el puntero a la documentación KYC off-chain (H-11) queda **no autenticado**, lo que afecta a la trazabilidad/auditoría regulatoria.

**Recomendación acotada.** Añadir `bytes32 uriHash` al `CLAIM_TYPEHASH` (cambio off-chain breaking, a documentar en `CHANGELOG_ABIS.md` como el del `nonce`), o, si se decide no firmarlo, declararlo explícitamente como campo no autenticado en `SECURITY.md` y en el changelog.

---

### AF-04 · MEDIA — `createIdentityWithClaim`: el `walletOwner` firmado es la factory (front-running)

**Qué ocurre.** La ruta inicializa el clon con la factory como owner temporal, llama `addClaim` (que toma `owner()` para el digest, `IdentityCloneable.sol:159`) y solo después transfiere la propiedad (`IdentityCloneFactory.sol:95-103`). Por tanto el issuer firma `walletOwner = factory`; el único vínculo con el titular es `verifyingContract` (dirección del clon), **predecible** por el nonce de la factory.

**Impacto real.** Un atacante que observe la transacción pendiente puede ejecutar antes `createIdentityWithClaim(owner = atacante, ...)` con la misma firma: la crea en la dirección esperada con owner atacante; la llamada del titular usa otra dirección de clon y **revierte** por `"Signature signer mismatch"`. El atacante queda como owner de una identidad con claims válidos. El impacto se limita porque `IdentityRegistry.registerIdentity` es `onlyOwner` (habría que registrar la identidad del atacante contra la wallet de la víctima), pero una herramienta que use la dirección precalculada sin comprobar `owner()` puede acabar registrando una identidad controlada por el atacante. D-027 documenta `walletOwner = factory` pero **no** el front-running.

**Recomendación acotada.** En esta ruta, incluir en el digest el `owner` final (dos pasos: `initialize(owner final)` + firma con `walletOwner = owner`, cediendo temporalmente el permiso de `addClaim`), o exigir `msg.sender == owner`; y en la verificación post-alta de las herramientas, comprobar `identity.owner()`.

---

### AF-05 · MEDIA — El fail-closed de RF-012 no cubre el array de módulos del token

**Qué ocurre.** El `ComplianceAggregator` es fail-closed con 0 módulos (`ComplianceAggregator.sol:155-159`). Pero el **token** no: `canTransfer` recorre `complianceModules` y, si el array está vacío, sale del bucle y `return true` (`TokenCloneable.sol:434-440`). `removeComplianceModule` puede vaciar el array (`:185-191`) sin ningún mínimo obligatorio.

**Impacto real.** Retirar el aggregator (o el último módulo) deja el token **sin ninguna regla de compliance**, solo con pausa/congelación/identidad. Es exactamente el patrón "0 módulos = permitir todo" que RF-012 declaró vulnerabilidad (H-22) en el aggregator, aquí a nivel del token. Lo ejecuta `COMPLIANCE_ROLE` (rol de confianza), por lo que **no es una escalada de privilegio**, pero sí una inconsistencia de diseño y un riesgo operativo (una retirada "temporal" desactiva en silencio todas las reglas). El test dedicado `RF012_AggregatorFailClosed.t.sol:270` solo cubre retirar el módulo *interno* del aggregator, no el aggregator del token.

**Recomendación acotada.** Aplicar la misma política en el token (por ejemplo, exigir un mínimo de módulos activos configurable, o que `removeComplianceModule` no pueda dejar el array vacío salvo `pause()`), y añadir el test de regresión que hoy falta.

---

### AF-06 · MEDIA — La matriz de trazabilidad de Fase 4 está desactualizada

**Qué ocurre.** `RepoTecnico/pruebas/matriz_criterios.md` se declara "Fase 4" pero su línea base es anterior al cierre: habla de "18 archivos, **353 tests**" y de 10 invariantes en 2 archivos (`:23-28`), mientras el repo final tiene **368 tests** en 22 suites y **19 `invariant_*`**. De sus **9 FALTA**, al menos 8 ya están cubiertos:

| FALTA declarado (`matriz_criterios.md`) | Prueba real hoy |
|---|---|
| `test_RF012_retirar_ultimo_modulo_bloquea` (`:257`) | `test/RF012_AggregatorFailClosed.t.sol:270` |
| `test_RNF005_cambio_topics_afecta_isVerified` (`:227`) | `test/RF011_FailClosed.t.sol:158` |
| `test_RNF005_set_claim_topics_registry_cero_revierte` (`:230`) | `test/RF011_FailClosed.t.sol:178-180` |
| `test_RF002_transfer_from_sin_allowance_revierte` (`:180`) | `test/TokenReentrancy.t.sol:372` |
| `test_RF005_initialization_implementacion_bloqueada` (`:144`) | `test/TokenCloneFactory.t.sol:224-226` |
| `test_RF005_no_storage_muerto_tokenName` (`:148`) | `test/TokenCloneFactory.t.sol:237-246` |
| `test_RF001_registries_owner_tras_renuncia` (`:55`) | `test/TrustedIssuersRegistry.t.sol` (suite en verde) |
| `ci_check_RF010_secret_scan_sin_hallazgos` (`:213`) | `script/ci/check_secrets.sh` + job `ci-checks` de `.gitlab-ci.yml:182-190` |

Queda **realmente abierto** `ci_check_RF006_mitigacion_con_test`: `check_docs.sh:6` lo cita como concretado, pero el script no comprueba que las mitigaciones de `SECURITY.md` referencien un test/gate (§(g) solo valida que los `test_*`/`ci_check_*` citados existan).

**Impacto real.** El artefacto que certifica la cobertura de los 142 criterios de aceptación de Fase 4 sobreafirma huecos y oculta que la mayoría ya está cerrada; además, un gate documentado se da por implementado sin estarlo. No es un fallo de los contratos, sino de la evidencia de la fase.

**Recomendación acotada.** Regenerar la matriz contra el estado final (368 tests/19 invariantes), corregir el recuento y el mapa criterio→prueba, y o bien implementar `ci_check_RF006_mitigacion_con_test` en `check_docs.sh` o retirarlo de la lista de checks.

---

### AF-07 · MEDIA — El despliegue canónico deja el token inoperable y la verificación es "verde"

**Qué ocurre.** `DeployFullStack` crea y registra una identidad **sin ningún claim** (`DeployFullStack.s.sol:112-113`), y configura la política de topics con topic 1 (`:60-61`). Por RF-011 (`isVerified` fail-closed, `TokenCloneable.sol:341-412`), `isVerified(deployer) == false`, de modo que cualquier `mint` revierte (`:269`). Tampoco se configuran `maxBurnPerTx`/`maxForcedPerTx` (quedan en 0 = desactivados) ni destinos autorizados. `deploy.sh` verifica bytecode y estado (`deploy.sh:220-297`) pero **no** ejecuta un `mint`/`transfer` de humo, así que termina con "Despliegue verificado correctamente" sobre un token que no puede emitir.

**Impacto real.** Falsa sensación de despliegue operativo; el operador descubre la inoperancia al intentar el primer `mint`. Para RNF de disponibilidad y para los manuales, el estado "verificado" debería implicar "operativo".

**Recomendación acotada.** Añadir al script de verificación un smoke test acotado: firmar un claim de ejemplo (clave efímera de issuer local), `mint` a esa wallet y `transfer` a otra verificada, comprobando saldos; o, si se prefiere un token deliberadamente inerte, documentarlo en `deploy.sh` y en el runbook de despliegue.

---

### AF-08 · MEDIA — `CompleteDeploymentExample.s.sol` está roto desde RF-001

**Qué ocurre.** El "ejemplo completo" sigue llamando `addClaim` con firma vacía (`hex""`, `CompleteDeploymentExample.s.sol:158-175`). Con RF-001, `require(_signature.length == 65, "Invalid signature length")` (`IdentityCloneable.sol:150`) hace que `run()` **revierta**, y los mensajes "Investor1 can trade…" (`:196-197`) son falsos bajo `isVerified` fail-closed. El archivo se anuncia en `README.md:129` y `CLAIM_TOPICS_REGISTRY_FACTORY.md:219`.

**Impacto real.** Cualquier lector/operador que lo ejecute como documentado obtiene un revert; erosiona la confianza en la documentación de despliegue.

**Recomendación acotada.** Marcar el script como obsoleto en su cabecera y en los dos documentos que lo citan, apuntando al camino canónico (`DeployFullStack.s.sol` + `deploy.sh`); o sustituir las firmas por EIP-712 válidas con el helper `sc/test/helpers/SigUtils.sol`.

---

### AF-09 · MEDIA — Instrucciones de despliegue hacia una API inexistente

**Qué ocurre.** `DeployComplianceAggregator.s.sol:34` imprime `aggregator.configureToken(tokenAddress, maxBalance, maxHolders, lockPeriod)`. `ComplianceAggregator` **no** tiene `configureToken`; su API real es `addModule(token, module)` / `removeModule(token, module)` gestionada por el token (`ComplianceAggregator.sol:86-143`).

**Impacto real.** El operador que siga los "Next Steps" emite una llamada inexistente; además sugiere un modelo (aggregator con owner global configurando tokens) que RF-012 retiró expresamente.

**Recomendación acotada.** Corregir o eliminar el bloque "Next Steps" (líneas 32-41) para reflejar `token.addComplianceModule(aggregator)` + `token.addModuleThroughAggregator(aggregator, module)`.

---

### AF-10 · MEDIA — Falta el runbook de migración exigido por D-019

**Qué ocurre.** D-019 exige "redeploy limpio con EIP-1167 **+ runbook de migración documentado**" (`requerimientos.md:129-130`, repetido en `documento_tecnico.md:270,775,789`). La búsqueda de "runbook" en todo `rwa-sc/**` solo devuelve las menciones del requisito y el backlog R-5; **no existe** un artefacto operativo (pasos, orden de llamadas, re-registro de identidades/issuers/topics, verificación post-redeploy).

**Impacto real.** Sin runbook, el ciclo de vida elegido (sin proxy) convierte cualquier redeploy en un procedimiento ad-hoc con riesgo de dejar el token inoperable (ver AF-07) o de perder la política de verificación.

**Recomendación acotada.** Crear `RepoTecnico/RUNBOOK_MIGRACION.md` con el procedimiento ensayado y enlazarlo desde `documento_tecnico.md` §ciclo de vida.

---

### AF-11 · MEDIA — Deriva documental del estado de la CI

**Qué ocurre.** `SECURITY.md` afirma en el catálogo de amenazas que "el pipeline de CI aún no existe (RF-009)" (`:45`) y en brechas abiertas que "RF-009 (`.gitlab-ci.yml`) sigue pendiente" (`:163-164`). El archivo `.gitlab-ci.yml` existe (Ciclo 11) con 7 etapas y `estado_proyecto.md` documenta el ciclo 11 completado y pipelines en verde (`:51,137,255`). A la inversa, la cabecera de `.gitlab-ci.yml:16-18` afirma que "el pipeline AÚN NO ha corrido en remoto", contradiciendo `estado_proyecto.md:255`. La propia `matriz_criterios.md:35` señala esa contradicción, pero el residuo sigue en `SECURITY.md` y en `.gitlab-ci.yml`.

**Impacto real.** Documentación de seguridad interna que contradice el repositorio; un lector externo no puede saber si los gates existen/corrieron.

**Recomendación acotada.** Alinear `SECURITY.md` y la cabecera de `.gitlab-ci.yml` con el estado real y añadir a `check_docs.sh` una comprobación barata: si `.gitlab-ci.yml` existe, `SECURITY.md` no puede contener "sigue pendiente" referido a RF-009.

---

## 5. Falsos positivos descartados (con motivo)

1. **Estado singleton cross-token de los módulos de compliance (H-19 / M-10).** `MaxHoldersCompliance.holderCount`/`tokenContract`, `MaxBalanceCompliance.tokenContract` y `TransferLockCompliance.lockEndTime` son singleton, pero **ya está catalogado** en `SECURITY.md:42` y en el backlog M-10 (`INFORME_OPTIMIZACION_V1.md:353`). No es un hallazgo nuevo; el aislamiento por token del aggregator (`tokenModules`) sí está probado (`test_RF012_aggregator_aislamiento_cross_token`).
2. **Arrays O(n) y vistas sin paginación (H-20 / M-11).** Conocidos y en backlog; `isVerified` ya evita el barrido de *todos* los issuers usando `getClaimIssuersForTopic`. Descartado como nuevo.
3. **Centralización de roles (H-06/D-021) y factories permissionless (H-07).** Conocidos, con gobernanza objetivo documentada; fuera del alcance de esta revisión.
4. **Falta de evento `TokenContractSet` en los tres módulos (H-34/QW-8).** Confirmado en código (`setTokenContract` en `MaxBalanceCompliance.sol:41`, `MaxHoldersCompliance.sol:61`, `TransferLockCompliance.sol:57`), pero **ya documentado** en `diccionario_datos.md:101` y `requerimientos.md:510,532` como backlog. No se re-cuenta.
5. **`MaxBalanceCompliance.transferred/created/destroyed` sin control de acceso.** Descartado: son no-op (no escriben estado), no hay superficie de ataque.
6. **`setMaxBurnPerTx`/`setMaxForcedPerTx` emiten `LimitsUpdated(maxBurn, maxForced)` con ambos valores aunque solo cambie uno.** Descartado: no explotable, solo ergonomía de indexación.
7. **Auto-registro del aggregator como módulo de sí mismo.** Se comprobó el razonamiento: en la llamada recursiva `msg.sender` pasa a ser el aggregator, `_isTokenRegistered[aggregator]` es `false` y `canTransfer` devuelve `false` sin recursión infinita. Solo produce autobloqueo recuperable con `removeModuleThroughAggregator`. Descartado.
8. **`createTokenWithRegistries(admin = address(factory))` dejaría el token sin roles (grant y renounce al mismo beneficiario).** Es auto-perjuicio del propio creador, sin impacto a terceros; el llamador controla todas las entradas. Descartado (anotado como "necesita verificación" solo si el despliegue automatizado pudiera pasar la factory como admin, cosa que `DeployFullStack` no hace).
9. **`check_coverage.sh` omite contratos sin líneas medibles (`:91`).** Descartado: los contratos de `src/` con código aparecen con `t > 0`; solo las interfaces (excluidas por D-017) dan `N/A (0/0)`. El agregado y el mínimo por contrato siguen siendo efectivos.
10. **Reentrancia (H-18/RF-002).** Sólido: `nonReentrant` en los cinco puntos de entrada (`TokenCloneable.sol:268,294,319,449,456`) y `canTransfer` es `view` (el compilador emite `STATICCALL`, el módulo no puede mutar estado). Descartado como vulnerabilidad.
11. **`isVerified` fail-closed y ERC-165.** Correctos y con tests; las llamadas externas se validan con `data.length >= 32` (`TokenCloneable.sol:179,399`). Descartado.
12. **Dominio EIP-712 / replay entre cadenas.** Sólido: `chainId` y `verifyingContract` en el domain separator (`IdentityCloneable.sol:346-356`), `ECDSA` de OpenZeppelin para maleabilidad, nonce anti-replay tras revocación. Descartado.
13. **PII/KYC off-chain (H-11), observabilidad/indexer (H-12/H-21), catálogo ISO 25010 (H-09).** Fuera del alcance de código y ya trackeados; descartados.
14. **`abi_diff.sh`, `check_docs.sh`, `check_no_bypass_flag.sh`, `check_secrets.sh`, `forge fmt --check`, `forge test`.** Ejecutados: todos en verde con el toolchain fijado. No hay hallazgo.

---

## 6. Lo que está sólido (para no rehacer)

- **Suite de pruebas:** 368/368 en verde, 22 suites, 19 invariantes con handlers y "call properties" bien diseñados (`TokenGhosts` evita falsos verdes por `fail_on_revert`).
- **RF-002 (anti-reentrancia):** guard en los cinco puntos de entrada y `_forcedUpdate` explícito sin flag mutable; el gate `check_no_bypass_flag.sh` inspecciona el storage layout compilado, no el fuente.
- **RF-003 (ERC-165):** validación con `staticcall` + comprobación de longitud en token y aggregator; rechaza EOA, `address(0)`, contratos sin interfaz y `false`.
- **RF-011/RF-013 (fail-closed + vigencia):** `isVerified` exige registro, identidad, topics no vacíos, issuer autorizado por topic y `hasValidClaim` vigente/no revocado; cualquier fallo de llamada se trata como no válido.
- **RF-001/8c (EIP-712):** `scheme == 1`, longitud 65, `ECDSA.tryRecover` con maleabilidad, `walletOwner` + `chainId` + `verifyingContract` + `nonce`; renovación y revocación coherentes; test adversarial de replay.
- **RF-004/D-022 (límites):** `authorizedDestinations` fail-closed, `maxBurnPerTx`/`maxForcedPerTx` por operación (0 = desactivado) y `maxSupply` que no puede quedar por debajo de `totalSupply` (`TokenCloneable.sol:257-261`).
- **RF-012 (aggregator):** fail-closed por token, gestión solo por el token (`onlyToken`), sin owner global; registro automático del token al primer módulo.
- **Seguridad de clones:** `_disableInitializers()` en las tres implementaciones (`TokenCloneable.sol:82-84`, `IdentityCloneable.sol:93-95`, `ClaimTopicsRegistryCloneable.sol:20-22`) y test de inicialización bloqueada (`TokenCloneFactory.t.sol:224-226`).
- **RF-010 (secretos/despliegue):** `deploy.sh` valida `chain-id` antes del broadcast, firma con keystore efímero (modo 600, `trap cleanup`), no usa `--private-key` en `argv` ni `keys.json`, y verifica bytecode/estado on-chain con `cast`.
- **Reproducibilidad:** submódulos pinneados, `solc 0.8.20`, `evm_version = paris`, `foundry.lock` y `.gas-snapshot` versionados.

---

## 7. Criterios de aceptación sugeridos para cerrar la Fase 4

**Bloqueantes de cierre (F4-B):**

1. **F4-B1 (AF-01):** `addComplianceModule` rechaza (o el despliegue verifica) módulos no configurados para el token; ningún módulo puede revertir el camino de transferencia por retorno mal formado. Test: módulo ERC-165 sin `tokenContract` → el token sigue operativo o falla con mensaje explícito, nunca `Panic`/revert opaco.
2. **F4-B2 (AF-02):** semántica de `paused()`/`frozen` fijada por escrito y cubierta con tests al menos para `mint`; decisión explícita para `burn`/`forcedTransfer`.
3. **F4-B3 (AF-06):** `matriz_criterios.md` regenerada contra el estado final (368 tests/19 invariantes), con los 9 FALTA revisados y `ci_check_RF006_mitigacion_con_test` implementado o retirado.
4. **F4-B4 (AF-07):** `deploy.sh` ejecuta un smoke test de `mint`+`transfer` sobre identidad con claim válida, o marca el token como "inerte por diseño" de forma explícita.

**Recomendados (F4-C):**

5. **F4-C1 (AF-03):** `uri` dentro del digest o declarado no autenticado en `SECURITY.md` + `CHANGELOG_ABIS.md`.
6. **F4-C2 (AF-04):** `owner` final en el digest de `createIdentityWithClaim` o control de acceso `msg.sender == owner`; verificación de `owner()` documentada para la operación.
7. **F4-C3 (AF-05):** política de mínimo de módulos en el token y test de regresión del array vacío.
8. **F4-C4 (AF-08/AF-09):** scripts de ejemplo corregidos o marcados obsoletos; ninguna instrucción impresa puede referenciar una función inexistente (añadir `grep` de los selectores impresos contra `forge inspect <C> methods` como check opcional).
9. **F4-C5 (AF-10):** `RUNBOOK_MIGRACION.md` creado y enlazado; ensayado al menos una vez en Anvil de GCP (`entornos_globales.md`).
10. **F4-C6 (AF-11/AF-15):** deriva documental a cero: `SECURITY.md`, `.gitlab-ci.yml` y `requerimientos.md` alineados con el estado real; referencias de línea corregidas.
11. **F4-C7 (AF-12/AF-13/AF-14):** conservar traza en `removeClaim` (o documentar eventos como única fuente), simetría de `removeModuleThroughAggregator` y uso efectivo de `DOC_RE` en `check_secrets.sh`.

**Condición de salida de la fase:** F4-B1..F4-B4 cerrados, F4-C1..F4-C7 planificados con responsable y fecha, y `run_local_ci.sh` en verde. La Fase 4 puede declararse cerrada con los F4-B; la promoción a producción queda sujeta a D-024 (auditoría externa) además de los criterios C-1..C-11 de `INFORME_OPTIMIZACION_V1.md`.

---

*Informe de solo lectura. No se ha modificado ningún archivo de `rwa-sc/sc/**` ni de `rwa-sc/RepoTecnico/**` salvo este entregable.*
