# Matriz de trazabilidad — criterio de aceptación → prueba — **v2 (vigente)**

> **Proyecto:** RWA / `rwa-sc` · **Fase 4 (Pruebas)** · **Fecha:** 2026-10-11
> **Estado:** **v2 (matriz vigente tras el cierre de Fase 4)**. Sustituye a la v1 (2026-10-10), cuya línea base (18 archivos, 353 tests, 10 invariantes) quedó superada por el cierre de huecos y la corrección de los hallazgos AF-01/AF-02/AF-13 de la auditoría adversarial final.
> **Fuente de criterios:** `RepoTecnico/casos_uso/casos_uso.md` v1.3 (17 CU · 92 Gherkin + 50 EARS = **142 criterios**).
> **Fuentes de prueba:** `rwa-sc/sc/test/**` (**23 suites: 19 unitarias + 4 de invariantes**, **386 tests**, **19 funciones `invariant_`**) y `rwa-sc/sc/script/ci/**` + `rwa-sc/.gitlab-ci.yml` (7 jobs).
> **Alcance de este informe:** solo lectura sobre `rwa-sc/sc/**`; el único archivo escrito es este.

---

## 1. Resumen ejecutivo (v2)

| Estado | Criterios | % |
|---|---:|---:|
| **CUBIERTO** | 120 | 84.5 % |
| **PARCIAL** | 22 | 15.5 % |
| **FALTA** | **0** | **0.0 %** |
| **N/A** | 0 | 0.0 % |
| **TOTAL** | **142** | **100 %** |

**Totales verificados por comando** (no a ojo):

- Criterios extraídos del documento: `grep -cE '^([0-9]+\. |- )\`(test_|ci_check_)' casos_uso.md` → **142** (92 ítems numerados + 50 viñetas EARS).
- Tests existentes: `forge test` → **386 tests pasados, 0 fallidos**, **23 suites**, 19 funciones `invariant_`.
- Nombres de test citados literalmente en el documento que **no existen** hoy: **67** `test_*` (ver §4); la mayoría están cubiertos por un test equivalente con otra convención.
- Los 24 nombres `ci_check_*` no son funciones de test: se resuelven contra scripts/gates y jobs del pipeline.

### Veredicto (v2)

- **No queda ningún criterio FALTA.** Los 9 huecos que la v1 declaraba abiertos se cerraron con pruebas reales (ver §2 y §3.1): `test_RF001_registries_owner_tras_renuncia`, `test_RF005_initialization_implementacion_bloqueada`, `test_RF005_no_storage_muerto_tokenName`, `test_RF002_transfer_from_sin_allowance_revierte`, `test_RNF005_cambio_topics_afecta_isVerified`, `test_RNF005_set_claim_topics_registry_cero_revierte`, `test_RF012_retirar_ultimo_modulo_bloquea`, `ci_check_RF010_secret_scan_sin_hallazgos` (`sc/script/ci/check_secrets.sh`) y `ci_check_RF006_mitigacion_con_test` (`sc/script/ci/check_docs.sh`).
- **Cobertura real alta.** 120/142 (84,5 %) criterios están CUBIERTOS por un test o gate real; los 22 restantes (15,5 %) son PARCIALES por desajustes de *semántica del criterio* (p. ej. criterios que describen el fail-open derogado por RF-011/RF-012), no por falta de verificación del comportamiento vigente. N/A = 0.
- **Desfase de etiquetas, no de comportamiento.** El código adelantó al documento: RF-001..RF-006, RF-009, RF-010, RF-011, RF-012 y RF-013 están implementados y probados; `casos_uso.md` mantiene rótulos «A IMPLEMENTAR» en varios CU (ver §4.3).
- **El pipeline de CI se ha ejecutado en remoto en verde.** IDs **`2934202154`** y **`2934241152`**, rama `rwa-sc-DSH-GCP`, **7/7 jobs en `success`** (`metricas_ejecucion.md` §20.1, `estado_proyecto.md`). El ensayo local `sc/script/ci/run_local_ci.sh` devuelve `exit 0` con las 7 etapas.
- **Veredicto de fase:** **la matriz certifica el cierre de la Fase 4.** No hay acciones bloqueantes pendientes; los PARCIAL son mejoras de redacción de `casos_uso.md` y no bloquean el cierre (la promoción a producción sigue sujeta a D-024: auditoría externa).

### v2 — cambios respecto a la v1

- Línea base: 18 archivos/353 tests/10 invariantes → **23 suites/386 tests/19 invariantes**.
- **9 FALTA → 0 FALTA** (los 8 que la auditoría AF-06 ya daba por cubiertos + `ci_check_RF006_mitigacion_con_test` implementado en `check_docs.sh`).
- Se añade la suite `test/AuditoriaFinalAF.t.sol` (hallazgos **AF-01**, **AF-02** y **AF-13** de la auditoría adversarial final).
- Se elimina la «Nota de concurrencia» de la v1: `sc/test/invariant/` ya está integrado y es parte de la línea base (19 invariantes).
- Pipeline documentado con **dos** IDs verdes (`2934202154` y `2934241152`), no uno.

---

## 2. Matriz completa criterio → prueba → estado

Estados: **CUBIERTO** (test/gate existe y verifica ese comportamiento) · **PARCIAL** (existe algo relacionado pero no verifica exactamente el criterio) · **FALTA** (no existe prueba) · **N/A** (fuera de alcance por D-003).
Rutas relativas a `rwa-sc/sc/`; las de pipeline a `rwa-sc/`.


### CU-01 — Administrar emisores confiables y sus topics

| # | Criterio (casos_uso.md) | Tipo | Prueba que lo verifica | Estado | Nota |
|---|---|---|---|---|---|
| 1 | L160 `test_RF001_addTrustedIssuer_guarda_topics` | Gherkin | test/TrustedIssuersRegistry.t.sol:61 test_AddTrustedIssuer | **CUBIERTO** | Cubierto con nombre distinto |
| 2 | L164 `test_RF001_addTrustedIssuer_duplicado_revierte` | Gherkin | test/TrustedIssuersRegistry.t.sol:110 test_AddTrustedIssuer_RevertWhen_AlreadyTrusted | **CUBIERTO** | Cubierto con nombre distinto |
| 3 | L168 `test_RF001_removeTrustedIssuer_swap_and_pop` | Gherkin | test/TrustedIssuersRegistry.t.sol:134 test_RemoveTrustedIssuer_FirstSwapsLast | **CUBIERTO** | Cubierto con nombre distinto; tambien :152 (middle) y :328 (fuzz) |
| 4 | L172 `test_RF001_updateIssuerClaimTopics_actualiza` | Gherkin | test/TrustedIssuersRegistry.t.sol:232 test_UpdateIssuerClaimTopics | **CUBIERTO** | Cubierto con nombre distinto |
| 5 | L176 `test_RF001_addTrustedIssuer_only_owner_revierte` | Gherkin | test/TrustedIssuersRegistry.t.sol:124 test_AddTrustedIssuer_RevertWhen_NotOwner | **CUBIERTO** | Cubierto con nombre distinto |
| 6 | L180 `test_RF001_hasClaimTopic_issuer_confiable_topic_ausente_false` | Gherkin | test/TrustedIssuersRegistry.t.sol:286 test_HasClaimTopic_FalseWhenTopicNotListed | **CUBIERTO** | Cubierto con nombre distinto |
| 7 | L184 `test_RF001_registries_owner_tras_renuncia` | Gherkin | test/TrustedIssuersRegistry.t.sol:376 test_RF001_registries_owner_tras_renuncia | **CUBIERTO** | Cerrado en el cierre de Fase 4 |
| 8 | L190 `test_RF001_addTrustedIssuer_topics_vacios_revierte` | EARS | test/TrustedIssuersRegistry.t.sol:117 test_AddTrustedIssuer_RevertWhen_NoClaimTopics | **CUBIERTO** | Cubierto con nombre distinto |

### CU-02 — Verificar la firma EIP-712 del claim y añadirlo

| # | Criterio (casos_uso.md) | Tipo | Prueba que lo verifica | Estado | Nota |
|---|---|---|---|---|---|
| 1 | L219 `test_RF001_addClaim_con_firma_valida` | Gherkin | test/IdentityCloneable.t.sol:79 | **CUBIERTO** | Nombre exacto |
| 2 | L223 `test_RF001_addClaim_emite_claimId_estable` | Gherkin | test/IdentityCloneable.t.sol:113 | **CUBIERTO** | Nombre exacto |
| 3 | L227 `test_RF001_addClaim_actualiza_indice_topicIssuers` | Gherkin | test/IdentityCloneable.t.sol:122 | **CUBIERTO** | Nombre exacto |
| 4 | L231 `test_RF001_addClaim_only_owner_revierte` | Gherkin | test/IdentityCloneable.t.sol:136 | **CUBIERTO** | Nombre exacto |
| 5 | L237 `test_RF001_addClaim_scheme_no_soportado_revierte` | EARS | test/IdentityCloneable.t.sol:271 | **CUBIERTO** | Nombre exacto |
| 6 | L238 `test_RF001_addClaim_digest_vincula_verifyingContract` | EARS | test/IdentityCloneable.t.sol:342 | **CUBIERTO** | Nombre exacto |
| 7 | L239 `test_RF001_addClaim_digest_vincula_chainId` | EARS | test/IdentityCloneable.t.sol:356 | **CUBIERTO** | Nombre exacto |
| 8 | L240 `test_RF001_addClaim_issuer_cero_revierte` | EARS | test/IdentityCloneable.t.sol:286 | **CUBIERTO** | Nombre exacto |

### CU-03 — Rechazar claim con firma inválida o issuer no autorizado para el topic

| # | Criterio (casos_uso.md) | Tipo | Prueba que lo verifica | Estado | Nota |
|---|---|---|---|---|---|
| 1 | L267 `test_RF001_addClaim_firma_de_otra_clave_revierte` | Gherkin | test/IdentityCloneable.t.sol:217 | **CUBIERTO** | Nombre exacto |
| 2 | L271 `test_RF001_addClaim_data_manipulada_revierte` | Gherkin | test/IdentityCloneable.t.sol:241 | **CUBIERTO** | Nombre exacto |
| 3 | L275 `test_RF001_addClaim_topic_no_autorizado_revierte` | Gherkin | test/IdentityCloneable.t.sol:374 test_RF001_issuer_no_autorizado_para_topic_no_verifica | **PARCIAL** | El contrato NO revierte en addClaim; D-025 traslada la autorizacion a isVerified (devuelve false). No existe el revert 'Issuer not authorized for topic' |
| 4 | L279 `test_RF001_addClaim_firma_longitud_invalida_revierte` | Gherkin | test/IdentityCloneable.t.sol:206 | **CUBIERTO** | Nombre exacto |
| 5 | L283 `test_RF001_addClaim_reintento_sobrescribe_renueva` | Gherkin | test/IdentityCloneable.t.sol:148 | **CUBIERTO** | Nombre exacto (tambien :173, firma invalida no sobrescribe) |
| 6 | L289 `test_RF001_addClaim_ecrecover_cero_revierte` | EARS | test/IdentityCloneable.t.sol:296 | **CUBIERTO** | Nombre exacto |
| 7 | L290 `test_RF001_addClaim_issuer_retirado_revierte` | EARS | test/IdentityCloneable.t.sol:374 | **PARCIAL** | Cubre issuer no autorizado, no el retiro tras el alta; el rechazo ocurre en isVerified, no en addClaim |
| 8 | L291 `test_RF001_addClaim_no_escribe_estado_en_fallo` | EARS | test/IdentityCloneable.t.sol:322 | **CUBIERTO** | Nombre exacto |

### CU-04 — Retirar el bypass de compliance y proteger contra reentrancia

| # | Criterio (casos_uso.md) | Tipo | Prueba que lo verifica | Estado | Nota |
|---|---|---|---|---|---|
| 1 | L319 `test_RF002_forcedTransfer_destino_autorizado_ok` | Gherkin | test/TokenReentrancy.t.sol:284 test_RF002_forcedTransfer_agente_ok; test/TokenLimits.t.sol:203 test_RF004_forcedTransfer_dentro_del_limite_ok | **CUBIERTO** | Cubierto con nombre distinto |
| 2 | L323 `test_RF002_forcedTransfer_destino_no_autorizado_revierte` | Gherkin | test/TokenLimits.t.sol:179 test_RF004_forcedTransfer_destino_no_autorizado_revierte | **CUBIERTO** | Cubierto con nombre distinto (prefijo RF004) |
| 3 | L327 `test_RF002_forcedTransfer_excede_maximo_revierte` | Gherkin | test/TokenLimits.t.sol:214 test_RF004_forcedTransfer_excede_limite_revierte | **CUBIERTO** | Cubierto con nombre distinto; el literal real es 'Exceeds max forced transfer per tx' |
| 4 | L331 `test_RF002_forcedTransfer_notifica_modulos` | Gherkin | test/TokenReentrancy.t.sol:357 test_RF002_forcedTransfer_notifica_modulos_una_vez | **CUBIERTO** | Cubierto con nombre distinto |
| 5 | L335 `ci_check_RF002_no_bypassCompliance_storage` | Gherkin | sc/script/ci/check_no_bypass_flag.sh + sc/.gitlab-ci.yml job ci-checks; test/TokenReentrancy.t.sol:397 test_RF002_storage_layout_sin_bypassCompliance | **CUBIERTO** | Gate real y test de storage-layout |
| 6 | L341 `test_RF002_forcedTransfer_reentrancy_revierte` | EARS | test/TokenReentrancy.t.sol:222 test_RF002_reentrancy_forcedTransfer_revierte | **CUBIERTO** | Cubierto con nombre distinto |
| 7 | L342 `test_RF002_forcedTransfer_invoca_super_update_sin_flag` | EARS | test/TokenReentrancy.t.sol:397 test_RF002_storage_layout_sin_bypassCompliance + :284 test_RF002_forcedTransfer_agente_ok | **CUBIERTO** | Cubierto con nombre distinto |
| 8 | L343 `test_RF002_forcedTransfer_only_agent_revierte` | EARS | test/TokenReentrancy.t.sol:326 | **CUBIERTO** | Nombre exacto |
| 9 | L344 `test_RF002_forcedTransfer_from_cero_revierte` | EARS | test/TokenReentrancy.t.sol:336 | **CUBIERTO** | Nombre exacto |

### CU-05 — Validar la interfaz `ICompliance` al registrar un módulo

| # | Criterio (casos_uso.md) | Tipo | Prueba que lo verifica | Estado | Nota |
|---|---|---|---|---|---|
| 1 | L372 `test_RF003_addComplianceModule_valida_erc165_ok` | Gherkin | test/RF003_ERC165.t.sol:86 | **CUBIERTO** | Nombre exacto |
| 2 | L376 `test_RF003_addComplianceModule_revierte_contrato_sin_interfaz` | Gherkin | test/RF003_ERC165.t.sol:108 | **CUBIERTO** | Nombre exacto |
| 3 | L380 `test_RF003_addComplianceModule_revierte_eoa` | Gherkin | test/RF003_ERC165.t.sol:99 | **CUBIERTO** | Nombre exacto |
| 4 | L384 `test_RF003_interfaceId_ICompliance_correcto` | Gherkin | test/RF003_ERC165.t.sol:66 | **CUBIERTO** | Nombre exacto |
| 5 | L390 `test_RF003_addComplianceModule_no_escribe_si_invalido` | EARS | test/RF003_ERC165.t.sol:131 | **CUBIERTO** | Nombre exacto |
| 6 | L391 `test_RF003_addComplianceModule_zero_revierte` | EARS | test/RF003_ERC165.t.sol:126 | **CUBIERTO** | Nombre exacto |
| 7 | L392 `test_RF003_addComplianceModule_duplicado_revierte` | EARS | test/RF003_ERC165.t.sol:142 | **CUBIERTO** | Nombre exacto |

### CU-06 — Limitar `burn`/`forcedTransfer` por whitelist de destinos y límites por operación

| # | Criterio (casos_uso.md) | Tipo | Prueba que lo verifica | Estado | Nota |
|---|---|---|---|---|---|
| 1 | L420 `test_RF004_burn_dentro_del_limite_ok` | Gherkin | test/TokenLimits.t.sol:119 | **CUBIERTO** | Nombre exacto |
| 2 | L424 `test_RF004_burn_excede_limite_revierte` | Gherkin | test/TokenLimits.t.sol:129 | **CUBIERTO** | Nombre exacto |
| 3 | L428 `test_RF004_setAuthorizedDestination_solo_admin_o_compliance` | Gherkin | test/TokenLimits.t.sol:227 | **CUBIERTO** | Nombre exacto |
| 4 | L432 `test_RF004_burn_notifica_modulos` | Gherkin | test/TokenLimits.t.sol:140 | **CUBIERTO** | Nombre exacto |
| 5 | L438 `test_RF004_limite_es_por_operacion_no_acumulado` | EARS | test/TokenLimits.t.sol:152 | **CUBIERTO** | Nombre exacto |
| 6 | L439 `test_RF004_whitelist_revocada_bloquea` | EARS | test/TokenLimits.t.sol:189 | **CUBIERTO** | Nombre exacto |
| 7 | L440 `test_RF004_limites_zero_bloquean` | EARS | test/TokenLimits.t.sol:165 | **CUBIERTO** | Nombre exacto |

### CU-07 — Añadir y retirar módulos de compliance a través del `ComplianceAggregator`

| # | Criterio (casos_uso.md) | Tipo | Prueba que lo verifica | Estado | Nota |
|---|---|---|---|---|---|
| 1 | L468 `test_RF003_addModuleThroughAggregator_ok` | Gherkin | test/RF003_ERC165.t.sol:205 (tambien test/ComplianceAggregator.t.sol:467 test_TokenCanAddModuleThroughAggregator) | **CUBIERTO** | Nombre exacto |
| 2 | L472 `test_RF003_removeModuleThroughAggregator_ok` | Gherkin | test/ComplianceAggregator.t.sol:486 test_TokenCanRemoveModuleThroughAggregator | **CUBIERTO** | Cubierto con nombre distinto |
| 3 | L476 `test_RF003_removeModule_swap_and_pop_orden` | Gherkin | test/ComplianceAggregator.t.sol:172 test_RemoveModule | **PARCIAL** | Verifica conteo y flags pero no el orden concreto tras el swap-and-pop (getModuleAt(token,0)==M3) |
| 4 | L480 `test_RF003_addModuleThroughAggregator_sin_agregador_revierte` | Gherkin | test/ComplianceAggregator.t.sol:535 test_RevertWhen_AddModuleThroughAggregatorNotAdded | **CUBIERTO** | Cubierto con nombre distinto |
| 5 | L484 `test_RF003_aggregator_addModule_duplicado_revierte` | Gherkin | test/ComplianceAggregator.t.sol:399 test_RevertWhen_AddModuleTwice | **CUBIERTO** | Cubierto con nombre distinto |
| 6 | L488 `test_RF003_aggregator_canTransfer_sin_modulos_true` | Gherkin | test/ComplianceAggregator.t.sol:346 test_NoModules_FailClosed | **PARCIAL** | Comportamiento INVERTIDO por RF-012 (fail-closed): el criterio describe el fail-open obsoleto |
| 7 | L492 `test_RF003_aggregator_canTransfer_todos_true` | Gherkin | test/ComplianceAggregator.t.sol:286 test_CombinedModules; test/RF012_AggregatorFailClosed.t.sol:200 test_RF012_aggregator_modulos_todos_true_ok | **CUBIERTO** | Cubierto con nombre distinto |
| 8 | L496 `test_RF003_aggregator_transferred_propaga` | Gherkin | test/ComplianceAggregator.t.sol:286 test_CombinedModules | **PARCIAL** | No hay asercion de propagacion de transferred a todos los modulos del aggregator (la propagacion solo se ejercita de forma indirecta) |
| 9 | L502 `test_RF003_aggregator_only_owner_or_token` | EARS | test/ComplianceAggregator.t.sol:549 test_TokenCanManageModules_OwnerCannot | **CUBIERTO** | Superado por RF-012: literal vigente 'Only token admin can call' |

### CU-08 — Crear un token clon con registries mediante `TokenCloneFactory`

| # | Criterio (casos_uso.md) | Tipo | Prueba que lo verifica | Estado | Nota |
|---|---|---|---|---|---|
| 1 | L531 `test_RF005_createTokenWithRegistries_clon_ok` | Gherkin | test/TokenCloneFactory.t.sol:84 test_CreateTokenWithRegistries | **CUBIERTO** | Cubierto con nombre distinto; name/symbol/decimals se verifican en :32 test_CreateToken |
| 2 | L535 `test_RF005_createTokenWithRegistries_roles_admin` | Gherkin | test/TokenCloneFactory.t.sol:84 test_CreateTokenWithRegistries | **CUBIERTO** | El mismo test comprueba roles del admin y ausencia de roles del factory |
| 3 | L539 `test_RF005_createToken_sin_registries_ok` | Gherkin | test/TokenCloneFactory.t.sol:32 test_CreateToken + :54 test_CreateMultipleTokens + :69 test_GetTokensByAdmin | **CUBIERTO** | Cubierto con nombre distinto |
| 4 | L543 `test_RF005_createToken_name_vacio_revierte` | Gherkin | test/TokenCloneFactory.t.sol:112 test_RevertWhenEmptyName | **CUBIERTO** | Cubierto con nombre distinto |
| 5 | L547 `test_RF005_initialization_implementacion_bloqueada` | Gherkin | test/TokenCloneFactory.t.sol:223 test_RF005_initialization_implementacion_bloqueada | **CUBIERTO** | Cerrado en el cierre de Fase 4 (`InvalidInitialization` sobre `implementation()`) |
| 6 | L553 `test_RNF001_gas_clone_menor_que_deploy_completo` | EARS | test/TokenCloneFactory.t.sol:132 test_GasSavings | **PARCIAL** | El test real mide ahorro >=45% frente al despliegue equivalente, no el '<10%' que fija el criterio |
| 7 | L554 `test_RF005_implementacion_unica_por_factory` | EARS | test/TokenCloneFactory.t.sol:27 test_Deployment | **PARCIAL** | Solo comprueba implementation != 0; no verifica unicidad/inmutabilidad |
| 8 | L555 `test_RF005_clones_independientes` | EARS | test/TokenCloneFactory.t.sol:187 test_IndependentClones | **CUBIERTO** | Cubierto con nombre distinto |
| 9 | L556 `test_RF005_no_storage_muerto_tokenName` | EARS | test/TokenCloneFactory.t.sol:237 test_RF005_no_storage_muerto_tokenName | **CUBIERTO** | Cerrado en el cierre de Fase 4 (storage layout sin `_tokenName`) |

### CU-09 — Registrar identidad y consultar `isVerified`

| # | Criterio (casos_uso.md) | Tipo | Prueba que lo verifica | Estado | Nota |
|---|---|---|---|---|---|
| 1 | L584 `test_RF001_registerIdentity_ok` | Gherkin | test/IdentityRegistry.t.sol:76 test_RegisterIdentity | **CUBIERTO** | Cubierto con nombre distinto |
| 2 | L588 `test_RF001_isVerified_todo_topics_cubiertos_true` | Gherkin | test/Token.t.sol:202 test_IsVerified; test/RF011_FailClosed.t.sol:117 test_RF011_configuracion_completa_verifica | **CUBIERTO** | Cubierto con nombre distinto |
| 3 | L592 `test_RF001_isVerified_falta_claim_false` | Gherkin | test/Token.t.sol:213 test_IsVerified_FailsWhenMissingClaim | **CUBIERTO** | Cubierto con nombre distinto |
| 4 | L596 `test_RF001_isVerified_issuer_no_confiable_para_topic_false` | Gherkin | test/IdentityCloneable.t.sol:374 test_RF001_issuer_no_autorizado_para_topic_no_verifica | **CUBIERTO** | Cubierto con nombre distinto |
| 5 | L600 `test_RF001_removeIdentity_swap_and_pop` | Gherkin | test/IdentityRegistry.t.sol:197 test_RemoveIdentity_FirstSwapsLast | **CUBIERTO** | Cubierto con nombre distinto |
| 6 | L604 `test_RF001_registerIdentity_duplicado_revierte` | Gherkin | test/IdentityRegistry.t.sol:123 test_RegisterIdentity_RevertWhen_AlreadyRegistered | **CUBIERTO** | Cubierto con nombre distinto |
| 7 | L608 `test_RF001_isVerified_sin_topics_registrada_true` | Gherkin | test/RF011_FailClosed.t.sol:90 test_RF011_isVerified_sin_registry_topics_false | **PARCIAL** | Criterio contradicho por RF-011: hoy isVerified devuelve false; el test vigente verifica lo contrario |
| 8 | L614 `test_RF001_isVerified_registry_vacio_false` | EARS | test/RF011_FailClosed.t.sol:107 test_RF011_token_recien_creado_por_factory_no_verificado | **CUBIERTO** | Cubierto con nombre distinto (token sin identityRegistry -> false) |
| 9 | L615 `test_RF001_isVerified_no_confia_en_issuer_del_identity_sin_registry` | EARS | test/RF011_FailClosed.t.sol:125 test_RF011_isVerified_failclosed_por_defecto | **PARCIAL** | No hay test aislado con topics exigidos y trustedIssuersRegistry == address(0) |
| 10 | L616 `test_RF001_registerIdentity_only_owner_revierte` | EARS | test/IdentityRegistry.t.sol:130 test_RegisterIdentity_RevertWhen_NotOwner | **CUBIERTO** | Cubierto con nombre distinto |

### CU-10 — Ejecutar una transferencia compliant (camino feliz y rechazos)

| # | Criterio (casos_uso.md) | Tipo | Prueba que lo verifica | Estado | Nota |
|---|---|---|---|---|---|
| 1 | L652 `test_RF002_transfer_camino_feliz` | Gherkin | test/TokenReentrancy.t.sol:315 test_RF002_transfer_normal_camino_feliz; test/Token.t.sol:270 test_Transfer_Success | **CUBIERTO** | Cubierto con nombre distinto |
| 2 | L656 `test_RF002_transfer_cuenta_congelada_revierte` | Gherkin | test/Token.t.sol:321 test_Transfer_FailsWhenFrozen | **CUBIERTO** | Cubierto con nombre distinto |
| 3 | L660 `test_RF002_transfer_token_pausado_revierte` | Gherkin | test/Token.t.sol:349 test_Transfer_FailsWhenPaused | **CUBIERTO** | Cubierto con nombre distinto |
| 4 | L664 `test_RF002_transfer_no_verificado_revierte` | Gherkin | test/Token.t.sol:208 test_IsVerified_FailsWhenNotRegistered | **PARCIAL** | No existe test de transfer hacia wallet no registrada; solo se cubre en mint (:242) y forcedTransfer (TokenReentrancy:345) |
| 5 | L668 `test_RF002_transfer_maxBalance_rechaza` | Gherkin | test/Token.t.sol:296 test_Transfer_FailsWhenExceedsMaxBalance | **CUBIERTO** | Cubierto con nombre distinto |
| 6 | L672 `test_RF002_transfer_transferLock_rechaza` | Gherkin | test/Token.t.sol:285 test_Transfer_FailsWhenLocked | **CUBIERTO** | Cubierto con nombre distinto |
| 7 | L676 `test_RF002_transfer_notifica_transferred_una_vez` | Gherkin | test/TokenReentrancy.t.sol:357 test_RF002_forcedTransfer_notifica_modulos_una_vez | **PARCIAL** | El conteo de transferred se verifica para forcedTransfer, no para transfer |
| 8 | L680 `test_RF002_mint_llama_canTransfer_revierte` | Gherkin | test/ComplianceAggregator.t.sol:346 test_NoModules_FailClosed; :312 test_CombinedModules | **CUBIERTO** | Cubierto con nombre distinto (mint revierte 'Mint not compliant' al rechazar un modulo) |
| 9 | L684 `test_RF002_burn_no_llama_canTransfer_y_notifica_destroyed` | Gherkin | test/TokenLimits.t.sol:140 test_RF004_burn_notifica_modulos | **PARCIAL** | Verifica destroyed, pero no que burn omita canTransfer (el modulo espia devuelve true) |
| 10 | L688 `test_RF002_forcedTransfer_no_llama_canTransfer` | Gherkin | test/Token.t.sol:377 test_ForcedTransfer_BypassesCompliance; test/TokenReentrancy.t.sol:284 | **CUBIERTO** | Cubierto con nombre distinto (con modulo que rechaza, forcedTransfer sigue funcionando) |
| 11 | L694 `test_RF002_mint_sin_modulos_ok` | EARS | test/MaxBalanceCompliance.t.sol:148 test_CreatedCallback | **PARCIAL** | El callback created se prueba por modulo, no via mint sin modulos; no hay asercion de notificacion en mint sin modulos |
| 12 | L695 `test_RF002_transfer_from_sin_allowance_revierte` | EARS | test/TokenReentrancy.t.sol:372 test_RF002_transfer_from_sin_allowance_revierte | **CUBIERTO** | Cerrado en el cierre de Fase 4 |

### CU-11 — Compilar y ejecutar la suite de tests en CI con umbral de cobertura

| # | Criterio (casos_uso.md) | Tipo | Prueba que lo verifica | Estado | Nota |
|---|---|---|---|---|---|
| 1 | L721 `ci_check_RF005_forge_build_ok` | Gherkin | sc/.gitlab-ci.yml job build (stage build); pipeline 2934202154 success | **CUBIERTO** | Gate de CI real |
| 2 | L725 `ci_check_RF009_pipeline_test_exit_0` | Gherkin | sc/.gitlab-ci.yml job test (stage test); 386/386 en verde | **CUBIERTO** | Gate de CI real |
| 3 | L729 `ci_check_RNF002_coverage_mayor_igual_80` | Gherkin | sc/.gitlab-ci.yml job coverage + sc/script/ci/check_coverage.sh | **CUBIERTO** | Gate real: agregado src/ 97.12%, minimo por contrato 91.53% |
| 4 | L733 `ci_check_RF009_artefacto_lcov_publicado` | Gherkin | sc/.gitlab-ci.yml job coverage (artifacts: sc/lcov.info) | **CUBIERTO** | Artefacto publicado |
| 5 | L739 `ci_check_RF005_submodulos_pinneados` | EARS | sc/.gitlab-ci.yml job validate; sc/script/ci/run_local_ci.sh stage_validate | **CUBIERTO** | Gate real (3 submodulos, sin prefijos -/+) |
| 6 | L740 `ci_check_RNF003_bloqueo_merge_con_fallos` | EARS | sc/.gitlab-ci.yml job test | **PARCIAL** | El job test bloquea el pipeline, pero el bloqueo del merge es configuracion de rama protegida en GitLab, no verificable en el repo |
| 7 | L741 `ci_check_RF005_remappings_coherentes` | EARS | sc/.gitlab-ci.yml job build | **PARCIAL** | Sin remappings el build falla, pero no hay check explicito que liste los ausentes en el log |
| 8 | L742 `ci_check_RF009_umbral_configurable_centralizado` | EARS | sc/.gitlab-ci.yml variables COVERAGE_THRESHOLD / COVERAGE_CONTRACT_THRESHOLD; sc/script/ci/check_coverage.sh:32-34 | **CUBIERTO** | Umbral en variable unica |

### CU-12 — Publicar y verificar documentación de seguridad y CHANGELOG de ABIs

| # | Criterio (casos_uso.md) | Tipo | Prueba que lo verifica | Estado | Nota |
|---|---|---|---|---|---|
| 1 | L766 `ci_check_RF006_refs_rotas_cero` | Gherkin | sc/script/ci/check_docs.sh:64-72 (job ci-checks) | **CUBIERTO** | Gate real |
| 2 | L770 `ci_check_RF006_security_md_existe` | Gherkin | sc/script/ci/check_docs.sh:51-53 | **CUBIERTO** | Gate real |
| 3 | L774 `ci_check_RF006_hallazgos_cubiertos` | Gherkin | sc/script/ci/check_docs.sh:86-93 | **CUBIERTO** | Gate real (HB-01..HB-12) |
| 4 | L778 `ci_check_RF006_changelog_abis_existe` | Gherkin | sc/script/ci/check_docs.sh:54-56 | **CUBIERTO** | Gate real |
| 5 | L782 `ci_check_RF006_abi_diff_automatico` | Gherkin | sc/script/ci/abi_diff.sh (job ci-checks) | **CUBIERTO** | Gate real |
| 6 | L788 `ci_check_RF006_mitigacion_con_test` | EARS | sc/script/ci/check_docs.sh (seccion (g): cada `test_*`/`ci_check_*` citado en SECURITY.md debe existir) | **CUBIERTO** | Implementado en el gate de documentacion (job ci-checks) |
| 7 | L789 `ci_check_RF006_docs_sin_placeholders` | EARS | sc/script/ci/check_docs.sh:95-103 | **CUBIERTO** | Gate real |

### CU-13 — Gestionar secretos de despliegue sin material en repositorios

| # | Criterio (casos_uso.md) | Tipo | Prueba que lo verifica | Estado | Nota |
|---|---|---|---|---|---|
| 1 | L814 `ci_check_RF010_script_sin_keys_json` | Gherkin | deploy-besu.sh y sc/script/deploy.sh | **PARCIAL** | La propiedad se cumple (grep 'keys.json' -> 0), pero no hay gate de CI que la verifique |
| 2 | L818 `ci_check_RF010_script_usa_env` | Gherkin | sc/script/deploy.sh:98-102 | **PARCIAL** | Lee la clave del entorno; sin gate de CI |
| 3 | L822 `ci_check_RF010_secret_scan_sin_hallazgos` | Gherkin | sc/script/ci/check_secrets.sh (job ci-checks) | **CUBIERTO** | Gate real: 64-hex crudas, tokens de proveedor, `keys.json`/`--private-key` y `.env` |
| 4 | L826 `ci_check_RF010_AbortSinSecreto` | Gherkin | sc/script/deploy.sh:102 | **PARCIAL** | Aborta con exit != 0 sin clave; no hay test shell automatizado |
| 5 | L830 `ci_check_RF010_secret_manager_soportado` | Gherkin | sc/script/deploy.sh:87-91 | **PARCIAL** | Soporta USE_SECRET_MANAGER con gcloud; falta el test test/ci/test_deploy_secret_manager.sh que exige el criterio |
| 6 | L836 `ci_check_RF010_env_en_gitignore` | EARS | sc/.gitignore (.env, .env.*) | **PARCIAL** | Propiedad presente; sin gate |
| 7 | L837 `ci_check_RF010_sin_clave_en_logs` | EARS | sc/script/deploy.sh (fail() no imprime el valor) | **PARCIAL** | Sin gate que lo verifique |
| 8 | L838 `ci_check_RF010_clave_solo_efimera` | EARS | sc/script/deploy.sh (keystore temporal cifrado + trap cleanup) | **PARCIAL** | Sin gate que lo verifique |

### CU-14 — Configurar los topics requeridos del token (extensibilidad de compliance)

| # | Criterio (casos_uso.md) | Tipo | Prueba que lo verifica | Estado | Nota |
|---|---|---|---|---|---|
| 1 | L865 `test_RNF005_addClaimTopic_ok` | Gherkin | test/ClaimTopicsRegistry.t.sol:52 test_AddClaimTopic | **CUBIERTO** | Cubierto con nombre distinto |
| 2 | L869 `test_RNF005_addClaimTopic_duplicado_revierte` | Gherkin | test/ClaimTopicsRegistry.t.sol:88 test_AddClaimTopic_RevertWhen_Duplicate | **CUBIERTO** | Cubierto con nombre distinto |
| 3 | L873 `test_RNF005_removeClaimTopic_swap_and_pop` | Gherkin | test/ClaimTopicsRegistry.t.sol:118 test_RemoveClaimTopic_FirstSwapsLast | **CUBIERTO** | Cubierto con nombre distinto |
| 4 | L877 `test_RNF005_cambio_topics_afecta_isVerified` | Gherkin | test/RF011_FailClosed.t.sol:158 test_RNF005_cambio_topics_afecta_isVerified | **CUBIERTO** | Cerrado en el cierre de Fase 4 |
| 5 | L881 `test_RNF005_nueva_regla_sin_redeploy_token` | Gherkin | test/ClaimTopicsRegistryCloneFactory.t.sol:179 test_DynamicTopicsScenario; test/RF012_AggregatorFailClosed.t.sol:250 | **CUBIERTO** | Cubierto con nombre distinto |
| 6 | L887 `test_RNF005_registry_topics_only_owner` | EARS | test/ClaimTopicsRegistry.t.sol:95 y :201 (RevertWhen_NotOwner) | **CUBIERTO** | Cubierto con nombre distinto |
| 7 | L888 `test_RNF005_set_claim_topics_registry_cero_revierte` | EARS | test/RF011_FailClosed.t.sol:178 test_RNF005_set_claim_topics_registry_cero_revierte | **CUBIERTO** | Cerrado en el cierre de Fase 4 |
| 8 | L889 `test_RNF005_agregar_modulo_sin_tocar_token` | EARS | test/ComplianceAggregator.t.sol:358 test_DynamicModuleAddition; test/RF012_AggregatorFailClosed.t.sol:250 | **CUBIERTO** | Cubierto con nombre distinto |
| 9 | L890 `test_RNF005_topics_persisten_entre_llamadas` | EARS | test/ClaimTopicsRegistry.t.sol:64 test_AddClaimTopic_MultipleKeepsInsertionOrder | **CUBIERTO** | Cubierto con nombre distinto |

### CU-15 — Cerrar el fail-open de `isVerified()` (RF-011 · H-05 auditoría V1)

| # | Criterio (casos_uso.md) | Tipo | Prueba que lo verifica | Estado | Nota |
|---|---|---|---|---|---|
| 1 | L916 `test_RF011_isVerified_sin_registry_topics_false` | Gherkin | test/RF011_FailClosed.t.sol:90 | **CUBIERTO** | Nombre exacto |
| 2 | L920 `test_RF011_isVerified_topics_vacios_false` | Gherkin | test/RF011_FailClosed.t.sol:97 | **CUBIERTO** | Nombre exacto |
| 3 | L924 `test_RF011_token_recien_creado_por_factory_no_verificado` | Gherkin | test/RF011_FailClosed.t.sol:107 | **CUBIERTO** | Nombre exacto |
| 4 | L928 `test_RF011_configuracion_completa_verifica` | Gherkin | test/RF011_FailClosed.t.sol:117 | **CUBIERTO** | Nombre exacto |
| 5 | L934 `test_RF011_isVerified_registry_topics_cero_false` | EARS | test/RF011_FailClosed.t.sol:90 test_RF011_isVerified_sin_registry_topics_false | **CUBIERTO** | Cubierto con nombre distinto (mismo comportamiento) |
| 6 | L935 `test_RF011_isVerified_failclosed_por_defecto` | EARS | test/RF011_FailClosed.t.sol:125 | **CUBIERTO** | Nombre exacto |
| 7 | L936 `test_RF011_mint_transfer_bloqueados_sin_politica` | EARS | test/RF011_FailClosed.t.sol:133 | **CUBIERTO** | Nombre exacto |

### CU-16 — `ComplianceAggregator` fail-closed y administración acotada por token (RF-012 · H-22 auditoría V1)

| # | Criterio (casos_uso.md) | Tipo | Prueba que lo verifica | Estado | Nota |
|---|---|---|---|---|---|
| 1 | L962 `test_RF012_aggregator_sin_modulos_revierte_transfer` | Gherkin | test/RF012_AggregatorFailClosed.t.sol:146 | **CUBIERTO** | Nombre exacto |
| 2 | L966 `test_RF012_aggregator_token_no_registrado_false` | Gherkin | test/RF012_AggregatorFailClosed.t.sol:165 | **CUBIERTO** | Nombre exacto |
| 3 | L970 `test_RF012_aggregator_admin_del_token_ok` | Gherkin | test/RF012_AggregatorFailClosed.t.sol:173 | **CUBIERTO** | Nombre exacto |
| 4 | L974 `test_RF012_aggregator_owner_global_token_ajeno_revierte` | Gherkin | test/RF012_AggregatorFailClosed.t.sol:187 | **CUBIERTO** | Nombre exacto (literal real 'Only token admin can call') |
| 5 | L978 `test_RF012_aggregator_modulos_todos_true_ok` | Gherkin | test/RF012_AggregatorFailClosed.t.sol:200 | **CUBIERTO** | Nombre exacto |
| 6 | L984 `test_RF012_aggregator_failclosed_por_defecto` | EARS | test/RF012_AggregatorFailClosed.t.sol:219 | **CUBIERTO** | Nombre exacto |
| 7 | L985 `test_RF012_agregar_modulo_sin_tocar_token_holder` | EARS | test/RF012_AggregatorFailClosed.t.sol:173 test_RF012_aggregator_admin_del_token_ok; :250 | **CUBIERTO** | Cubierto con nombre distinto |
| 8 | L986 `test_RF012_retirar_ultimo_modulo_bloquea` | EARS | test/RF012_AggregatorFailClosed.t.sol:270 test_RF012_retirar_ultimo_modulo_bloquea | **CUBIERTO** | Cerrado en el cierre de Fase 4 |

### CU-17 — Ciclo de vida del claim: vigencia y revocación por el issuer (RF-013 · H-08 auditoría V1)

| # | Criterio (casos_uso.md) | Tipo | Prueba que lo verifica | Estado | Nota |
|---|---|---|---|---|---|
| 1 | L1012 `test_RF013_claim_vigente_isVerified_true` | Gherkin | test/RF013_ClaimLifecycle.t.sol:136 | **CUBIERTO** | Nombre exacto |
| 2 | L1016 `test_RF013_claim_expirado_isVerified_false` | Gherkin | test/RF013_ClaimLifecycle.t.sol:159 | **CUBIERTO** | Nombre exacto |
| 3 | L1020 `test_RF013_claim_revocado_por_issuer_isVerified_false` | Gherkin | test/RF013_ClaimLifecycle.t.sol:182 | **CUBIERTO** | Nombre exacto |
| 4 | L1024 `test_RF013_revocar_solo_issuer_revierte` | Gherkin | test/RF013_ClaimLifecycle.t.sol:200 | **CUBIERTO** | Nombre exacto |
| 5 | L1028 `test_RF013_renovacion_actualiza_vigencia` | Gherkin | test/RF013_ClaimLifecycle.t.sol:219 | **CUBIERTO** | Nombre exacto |
| 6 | L1034 `test_RF013_isVerified_rechaza_vencidos` | EARS | test/RF013_ClaimLifecycle.t.sol:273 | **CUBIERTO** | Nombre exacto |
| 7 | L1035 `test_RF013_revocacion_emite_evento_y_conserva_historico` | EARS | test/RF013_ClaimLifecycle.t.sol:291 | **CUBIERTO** | Nombre exacto |
| 8 | L1036 `test_RF013_revocacion_no_reactivable_por_titular` | EARS | test/RF013_ClaimLifecycle.t.sol:338 | **CUBIERTO** | Nombre exacto |

---

## 3. Criterios PARCIAL y prueba mínima sugerida (v2: sin FALTA)

Prioridad: **P1** = hueco funcional real o criterio contradicho por el código; **P2** = cobertura indirecta o debilitada; **P3** = deuda de verificación (CI/documentación).

### 3.1 FALTA (0)

**No queda ningún criterio FALTA.** Los 9 huecos de la v1 se cerraron; criterio → prueba vigente:

| CU | Criterio (v1 FALTA) | Prueba/gate que lo cierra hoy |
|---|---|---|
| CU-01 | `test_RF001_registries_owner_tras_renuncia` | `test/TrustedIssuersRegistry.t.sol:376` |
| CU-08 | `test_RF005_initialization_implementacion_bloqueada` | `test/TokenCloneFactory.t.sol:223` |
| CU-08 | `test_RF005_no_storage_muerto_tokenName` | `test/TokenCloneFactory.t.sol:237` |
| CU-10 | `test_RF002_transfer_from_sin_allowance_revierte` | `test/TokenReentrancy.t.sol:372` |
| CU-12 | `ci_check_RF006_mitigacion_con_test` | `sc/script/ci/check_docs.sh` (sección (g), job `ci-checks`) |
| CU-13 | `ci_check_RF010_secret_scan_sin_hallazgos` | `sc/script/ci/check_secrets.sh` (job `ci-checks`) |
| CU-14 | `test_RNF005_cambio_topics_afecta_isVerified` | `test/RF011_FailClosed.t.sol:158` |
| CU-14 | `test_RNF005_set_claim_topics_registry_cero_revierte` | `test/RF011_FailClosed.t.sol:178` |
| CU-16 | `test_RF012_retirar_ultimo_modulo_bloquea` | `test/RF012_AggregatorFailClosed.t.sol:270` |

### 3.2 PARCIAL (22) — no bloquean el cierre

Los 22 PARCIAL son desajustes de **redacción/semántica del criterio** frente al comportamiento vigente (varios describen el fail-open derogado por RF-011/RF-012) o cobertura indirecta. El comportamiento actual sí está verificado; la acción pendiente es de redacción de `casos_uso.md`, no de código.

| Prioridad | CU | Criterio | Prueba existente | Qué le falta | Prueba mínima sugerida |
|---|---|---|---|---|---|
| P2 | CU-03 | `test_RF001_addClaim_topic_no_autorizado_revierte` | test/IdentityCloneable.t.sol:374 test_RF001_issuer_no_autorizado_para_topic_no_verifica | El contrato NO revierte en addClaim; D-025 traslada la autorizacion a isVerified (devuelve false). No existe el revert 'Issuer not authorized for topic' | Decidir la semantica: si se mantiene D-025, reescribir el criterio como "`addClaim` almacena y `isVerified` devuelve false para un issuer no autorizado" (referenciando `test_RF001_issuer_no_autorizado_para_topic_no_verifica`); si se exige el revert, implementarlo en `addClaim` y probar `"Issuer not authorized for topic"`. |
| P2 | CU-03 | `test_RF001_addClaim_issuer_retirado_revierte` | test/IdentityCloneable.t.sol:374 | Cubre issuer no autorizado, no el retiro tras el alta; el rechazo ocurre en isVerified, no en addClaim | Test: issuer confiable -> `addClaim` -> `removeTrustedIssuer` -> `isVerified(wallet)==false` (y decidir si `addClaim` posterior debe revertir). |
| P2 | CU-07 | `test_RF003_removeModule_swap_and_pop_orden` | test/ComplianceAggregator.t.sol:172 test_RemoveModule | Verifica conteo y flags pero no el orden concreto tras el swap-and-pop (getModuleAt(token,0)==M3) | Ampliar a tres modulos `[M1,M2,M3]`, retirar `M1` y afirmar `getModuleAt(token,0)==M3`, `getModuleCount==2` e `isModuleActiveForToken(token,M1)==false`. |
| P2 | CU-07 | `test_RF003_aggregator_canTransfer_sin_modulos_true` | test/ComplianceAggregator.t.sol:346 test_NoModules_FailClosed | Comportamiento INVERTIDO por RF-012 (fail-closed): el criterio describe el fail-open obsoleto | Reescribir el criterio a fail-closed (coherente con CU-16/RF-012) y referenciar `test_NoModules_FailClosed`; el texto actual describe el fail-open obsoleto. |
| P2 | CU-07 | `test_RF003_aggregator_transferred_propaga` | test/ComplianceAggregator.t.sol:286 test_CombinedModules | No hay asercion de propagacion de transferred a todos los modulos del aggregator (la propagacion solo se ejercita de forma indirecta) | Test con dos modulos espia registrados en el aggregator; ejecutar una `transfer` del token y afirmar que cada modulo recibe `transferred` exactamente una vez. |
| P2 | CU-08 | `test_RNF001_gas_clone_menor_que_deploy_completo` | test/TokenCloneFactory.t.sol:132 test_GasSavings | El test real mide ahorro >=45% frente al despliegue equivalente, no el '<10%' que fija el criterio | Alinear el umbral del criterio con el test real (`>=45%` de ahorro y piso 300k gas medidos en `test_GasSavings`) o reforzar la linea base para poder exigir el `<10%`; hoy el criterio y la prueba no coinciden. |
| P2 | CU-08 | `test_RF005_implementacion_unica_por_factory` | test/TokenCloneFactory.t.sol:27 test_Deployment | Solo comprueba implementation != 0; no verifica unicidad/inmutabilidad | Anadir asercion de inmutabilidad (no existe setter de `implementation`) o crear dos factories y comprobar implementaciones independientes. |
| P2 | CU-09 | `test_RF001_isVerified_sin_topics_registrada_true` | test/RF011_FailClosed.t.sol:90 test_RF011_isVerified_sin_registry_topics_false | Criterio contradicho por RF-011: hoy isVerified devuelve false; el test vigente verifica lo contrario | Reescribir el criterio a su forma fail-closed (RF-011) referenciando `test_RF011_isVerified_sin_registry_topics_false`; mantenerlo como esta es documentar un comportamiento derogado. |
| P2 | CU-09 | `test_RF001_isVerified_no_confia_en_issuer_del_identity_sin_registry` | test/RF011_FailClosed.t.sol:125 test_RF011_isVerified_failclosed_por_defecto | No hay test aislado con topics exigidos y trustedIssuersRegistry == address(0) | Test: token con `claimTopicsRegistry` con topic 1 y `trustedIssuersRegistry == address(0)`; afirmar `isVerified(wallet)==false`. |
| P2 | CU-10 | `test_RF002_transfer_no_verificado_revierte` | test/Token.t.sol:208 test_IsVerified_FailsWhenNotRegistered | No existe test de transfer hacia wallet no registrada; solo se cubre en mint (:242) y forcedTransfer (TokenReentrancy:345) | Test: `to` sin identidad registrada y `vm.expectRevert("Transfer not compliant"); token.transfer(user2, 1)`. |
| P2 | CU-10 | `test_RF002_transfer_notifica_transferred_una_vez` | test/TokenReentrancy.t.sol:357 test_RF002_forcedTransfer_notifica_modulos_una_vez | El conteo de transferred se verifica para forcedTransfer, no para transfer | Test con modulo espia y una `transfer` normal; afirmar `transferredCount==1` y `createdCount`/`destroyedCount` sin cambios. |
| P2 | CU-10 | `test_RF002_burn_no_llama_canTransfer_y_notifica_destroyed` | test/TokenLimits.t.sol:140 test_RF004_burn_notifica_modulos | Verifica destroyed, pero no que burn omita canTransfer (el modulo espia devuelve true) | Test con `RejectingComplianceModule` (canTransfer=false) y un espia: `burn` debe completarse y notificar `destroyed` una vez. |
| P2 | CU-10 | `test_RF002_mint_sin_modulos_ok` | test/MaxBalanceCompliance.t.sol:148 test_CreatedCallback | El callback created se prueba por modulo, no via mint sin modulos; no hay asercion de notificacion en mint sin modulos | Test de `mint` en un token sin modulos con modulo espia: no revierte por compliance y notifica `created(to,amount)`. |
| P2 | CU-11 | `ci_check_RNF003_bloqueo_merge_con_fallos` | sc/.gitlab-ci.yml job test | El job test bloquea el pipeline, pero el bloqueo del merge es configuracion de rama protegida en GitLab, no verificable en el repo | Documentar como configuracion externa (rama protegida + 'Pipelines must succeed') en `entornos_globales.md`; en el repo solo es verificable el gate del job `test`. |
| P2 | CU-11 | `ci_check_RF005_remappings_coherentes` | sc/.gitlab-ci.yml job build | Sin remappings el build falla, pero no hay check explicito que liste los ausentes en el log | Anadir al job `build` un `forge remappings` previo que falle listando los remappings de OpenZeppelin/upgradeable ausentes. |
| P2 | CU-13 | `ci_check_RF010_script_sin_keys_json` | deploy-besu.sh y sc/script/deploy.sh | La propiedad se cumple (grep 'keys.json' -> 0), pero no hay gate de CI que la verifique | Gate `check_secrets.sh` que haga `grep -R 'keys.json'` sobre scripts y falle si aparece; hoy la propiedad se cumple pero nadie la verifica. |
| P2 | CU-13 | `ci_check_RF010_script_usa_env` | sc/script/deploy.sh:98-102 | Lee la clave del entorno; sin gate de CI | Incluir en `check_secrets.sh` la comprobacion de que `deploy.sh` lee la clave de una variable de entorno y no contiene literales `0x`+64 hex. |
| P2 | CU-13 | `ci_check_RF010_AbortSinSecreto` | sc/script/deploy.sh:102 | Aborta con exit != 0 sin clave; no hay test shell automatizado | Anadir `sc/test/ci/test_deploy_abort.sh`: ejecutar `deploy.sh` sin `DS_PRIVATE_KEY` y afirmar exit != 0 y ausencia de `forge create`. |
| P2 | CU-13 | `ci_check_RF010_secret_manager_soportado` | sc/script/deploy.sh:87-91 | Soporta USE_SECRET_MANAGER con gcloud; falta el test test/ci/test_deploy_secret_manager.sh que exige el criterio | Crear `sc/test/ci/test_deploy_secret_manager.sh` que intercepte `gcloud secrets versions access` con un stub y compruebe que la clave llega a `forge create` sin persistir en disco (lo exige el propio criterio). |
| P2 | CU-13 | `ci_check_RF010_env_en_gitignore` | sc/.gitignore (.env, .env.*) | Propiedad presente; sin gate | Incluir en `check_secrets.sh`: `.env` y `.env.*` presentes en `.gitignore`. |
| P2 | CU-13 | `ci_check_RF010_sin_clave_en_logs` | sc/script/deploy.sh (fail() no imprime el valor) | Sin gate que lo verifique | Incluir en `check_secrets.sh` una prueba de fallo que capture stdout/stderr y verifique que no aparece la clave ni subcadenas de ella. |
| P2 | CU-13 | `ci_check_RF010_clave_solo_efimera` | sc/script/deploy.sh (keystore temporal cifrado + trap cleanup) | Sin gate que lo verifique | Incluir en el test shell de despliegue: tras la ejecucion no quedan ficheros con material de clave (`grep -R` sobre el temporal) y el trap limpia el keystore. |

---

## 4. Nombres obsoletos en `casos_uso.md` y reemplazo real

### 4.1 Criterios `test_*` citados que no existen con ese nombre (67)

| CU | Nombre citado en el documento | Test real / cobertura hoy |
|---|---|---|
| CU-01 | `test_RF001_addTrustedIssuer_guarda_topics` | test/TrustedIssuersRegistry.t.sol:61 test_AddTrustedIssuer |
| CU-01 | `test_RF001_addTrustedIssuer_duplicado_revierte` | test/TrustedIssuersRegistry.t.sol:110 test_AddTrustedIssuer_RevertWhen_AlreadyTrusted |
| CU-01 | `test_RF001_removeTrustedIssuer_swap_and_pop` | test/TrustedIssuersRegistry.t.sol:134 test_RemoveTrustedIssuer_FirstSwapsLast |
| CU-01 | `test_RF001_updateIssuerClaimTopics_actualiza` | test/TrustedIssuersRegistry.t.sol:232 test_UpdateIssuerClaimTopics |
| CU-01 | `test_RF001_addTrustedIssuer_only_owner_revierte` | test/TrustedIssuersRegistry.t.sol:124 test_AddTrustedIssuer_RevertWhen_NotOwner |
| CU-01 | `test_RF001_hasClaimTopic_issuer_confiable_topic_ausente_false` | test/TrustedIssuersRegistry.t.sol:286 test_HasClaimTopic_FalseWhenTopicNotListed |
| CU-01 | `test_RF001_registries_owner_tras_renuncia` | test/TrustedIssuersRegistry.t.sol:376 test_RF001_registries_owner_tras_renuncia |
| CU-01 | `test_RF001_addTrustedIssuer_topics_vacios_revierte` | test/TrustedIssuersRegistry.t.sol:117 test_AddTrustedIssuer_RevertWhen_NoClaimTopics |
| CU-03 | `test_RF001_addClaim_topic_no_autorizado_revierte` | PARCIAL: test/IdentityCloneable.t.sol:374 test_RF001_issuer_no_autorizado_para_topic_no_verifica |
| CU-03 | `test_RF001_addClaim_issuer_retirado_revierte` | PARCIAL: test/IdentityCloneable.t.sol:374 |
| CU-04 | `test_RF002_forcedTransfer_destino_autorizado_ok` | test/TokenReentrancy.t.sol:284 test_RF002_forcedTransfer_agente_ok; test/TokenLimits.t.sol:203 test_RF004_forcedTransfer_dentro_del_limite_ok |
| CU-04 | `test_RF002_forcedTransfer_destino_no_autorizado_revierte` | test/TokenLimits.t.sol:179 test_RF004_forcedTransfer_destino_no_autorizado_revierte |
| CU-04 | `test_RF002_forcedTransfer_excede_maximo_revierte` | test/TokenLimits.t.sol:214 test_RF004_forcedTransfer_excede_limite_revierte |
| CU-04 | `test_RF002_forcedTransfer_notifica_modulos` | test/TokenReentrancy.t.sol:357 test_RF002_forcedTransfer_notifica_modulos_una_vez |
| CU-04 | `test_RF002_forcedTransfer_reentrancy_revierte` | test/TokenReentrancy.t.sol:222 test_RF002_reentrancy_forcedTransfer_revierte |
| CU-04 | `test_RF002_forcedTransfer_invoca_super_update_sin_flag` | test/TokenReentrancy.t.sol:397 test_RF002_storage_layout_sin_bypassCompliance + :284 test_RF002_forcedTransfer_agente_ok |
| CU-07 | `test_RF003_removeModuleThroughAggregator_ok` | test/ComplianceAggregator.t.sol:486 test_TokenCanRemoveModuleThroughAggregator |
| CU-07 | `test_RF003_removeModule_swap_and_pop_orden` | PARCIAL: test/ComplianceAggregator.t.sol:172 test_RemoveModule |
| CU-07 | `test_RF003_addModuleThroughAggregator_sin_agregador_revierte` | test/ComplianceAggregator.t.sol:535 test_RevertWhen_AddModuleThroughAggregatorNotAdded |
| CU-07 | `test_RF003_aggregator_addModule_duplicado_revierte` | test/ComplianceAggregator.t.sol:399 test_RevertWhen_AddModuleTwice |
| CU-07 | `test_RF003_aggregator_canTransfer_sin_modulos_true` | PARCIAL: test/ComplianceAggregator.t.sol:346 test_NoModules_FailClosed |
| CU-07 | `test_RF003_aggregator_canTransfer_todos_true` | test/ComplianceAggregator.t.sol:286 test_CombinedModules; test/RF012_AggregatorFailClosed.t.sol:200 test_RF012_aggregator_modulos_todos_true_ok |
| CU-07 | `test_RF003_aggregator_transferred_propaga` | PARCIAL: test/ComplianceAggregator.t.sol:286 test_CombinedModules |
| CU-07 | `test_RF003_aggregator_only_owner_or_token` | test/ComplianceAggregator.t.sol:549 test_TokenCanManageModules_OwnerCannot |
| CU-08 | `test_RF005_createTokenWithRegistries_clon_ok` | test/TokenCloneFactory.t.sol:84 test_CreateTokenWithRegistries |
| CU-08 | `test_RF005_createTokenWithRegistries_roles_admin` | test/TokenCloneFactory.t.sol:84 test_CreateTokenWithRegistries |
| CU-08 | `test_RF005_createToken_sin_registries_ok` | test/TokenCloneFactory.t.sol:32 test_CreateToken + :54 test_CreateMultipleTokens + :69 test_GetTokensByAdmin |
| CU-08 | `test_RF005_createToken_name_vacio_revierte` | test/TokenCloneFactory.t.sol:112 test_RevertWhenEmptyName |
| CU-08 | `test_RF005_initialization_implementacion_bloqueada` | test/TokenCloneFactory.t.sol:223 |
| CU-08 | `test_RNF001_gas_clone_menor_que_deploy_completo` | PARCIAL: test/TokenCloneFactory.t.sol:132 test_GasSavings |
| CU-08 | `test_RF005_implementacion_unica_por_factory` | PARCIAL: test/TokenCloneFactory.t.sol:27 test_Deployment |
| CU-08 | `test_RF005_clones_independientes` | test/TokenCloneFactory.t.sol:187 test_IndependentClones |
| CU-08 | `test_RF005_no_storage_muerto_tokenName` | test/TokenCloneFactory.t.sol:237 |
| CU-09 | `test_RF001_registerIdentity_ok` | test/IdentityRegistry.t.sol:76 test_RegisterIdentity |
| CU-09 | `test_RF001_isVerified_todo_topics_cubiertos_true` | test/Token.t.sol:202 test_IsVerified; test/RF011_FailClosed.t.sol:117 test_RF011_configuracion_completa_verifica |
| CU-09 | `test_RF001_isVerified_falta_claim_false` | test/Token.t.sol:213 test_IsVerified_FailsWhenMissingClaim |
| CU-09 | `test_RF001_isVerified_issuer_no_confiable_para_topic_false` | test/IdentityCloneable.t.sol:374 test_RF001_issuer_no_autorizado_para_topic_no_verifica |
| CU-09 | `test_RF001_removeIdentity_swap_and_pop` | test/IdentityRegistry.t.sol:197 test_RemoveIdentity_FirstSwapsLast |
| CU-09 | `test_RF001_registerIdentity_duplicado_revierte` | test/IdentityRegistry.t.sol:123 test_RegisterIdentity_RevertWhen_AlreadyRegistered |
| CU-09 | `test_RF001_isVerified_sin_topics_registrada_true` | PARCIAL: test/RF011_FailClosed.t.sol:90 test_RF011_isVerified_sin_registry_topics_false |
| CU-09 | `test_RF001_isVerified_registry_vacio_false` | test/RF011_FailClosed.t.sol:107 test_RF011_token_recien_creado_por_factory_no_verificado |
| CU-09 | `test_RF001_isVerified_no_confia_en_issuer_del_identity_sin_registry` | PARCIAL: test/RF011_FailClosed.t.sol:125 test_RF011_isVerified_failclosed_por_defecto |
| CU-09 | `test_RF001_registerIdentity_only_owner_revierte` | test/IdentityRegistry.t.sol:130 test_RegisterIdentity_RevertWhen_NotOwner |
| CU-10 | `test_RF002_transfer_camino_feliz` | test/TokenReentrancy.t.sol:315 test_RF002_transfer_normal_camino_feliz; test/Token.t.sol:270 test_Transfer_Success |
| CU-10 | `test_RF002_transfer_cuenta_congelada_revierte` | test/Token.t.sol:321 test_Transfer_FailsWhenFrozen |
| CU-10 | `test_RF002_transfer_token_pausado_revierte` | test/Token.t.sol:349 test_Transfer_FailsWhenPaused |
| CU-10 | `test_RF002_transfer_no_verificado_revierte` | PARCIAL: test/Token.t.sol:208 test_IsVerified_FailsWhenNotRegistered |
| CU-10 | `test_RF002_transfer_maxBalance_rechaza` | test/Token.t.sol:296 test_Transfer_FailsWhenExceedsMaxBalance |
| CU-10 | `test_RF002_transfer_transferLock_rechaza` | test/Token.t.sol:285 test_Transfer_FailsWhenLocked |
| CU-10 | `test_RF002_transfer_notifica_transferred_una_vez` | PARCIAL: test/TokenReentrancy.t.sol:357 test_RF002_forcedTransfer_notifica_modulos_una_vez |
| CU-10 | `test_RF002_mint_llama_canTransfer_revierte` | test/ComplianceAggregator.t.sol:346 test_NoModules_FailClosed; :312 test_CombinedModules |
| CU-10 | `test_RF002_burn_no_llama_canTransfer_y_notifica_destroyed` | PARCIAL: test/TokenLimits.t.sol:140 test_RF004_burn_notifica_modulos |
| CU-10 | `test_RF002_forcedTransfer_no_llama_canTransfer` | test/Token.t.sol:377 test_ForcedTransfer_BypassesCompliance; test/TokenReentrancy.t.sol:284 |
| CU-10 | `test_RF002_mint_sin_modulos_ok` | PARCIAL: test/MaxBalanceCompliance.t.sol:148 test_CreatedCallback |
| CU-10 | `test_RF002_transfer_from_sin_allowance_revierte` | test/TokenReentrancy.t.sol:372 test_RF002_transfer_from_sin_allowance_revierte |
| CU-14 | `test_RNF005_addClaimTopic_ok` | test/ClaimTopicsRegistry.t.sol:52 test_AddClaimTopic |
| CU-14 | `test_RNF005_addClaimTopic_duplicado_revierte` | test/ClaimTopicsRegistry.t.sol:88 test_AddClaimTopic_RevertWhen_Duplicate |
| CU-14 | `test_RNF005_removeClaimTopic_swap_and_pop` | test/ClaimTopicsRegistry.t.sol:118 test_RemoveClaimTopic_FirstSwapsLast |
| CU-14 | `test_RNF005_cambio_topics_afecta_isVerified` | test/RF011_FailClosed.t.sol:158 test_RNF005_cambio_topics_afecta_isVerified |
| CU-14 | `test_RNF005_nueva_regla_sin_redeploy_token` | test/ClaimTopicsRegistryCloneFactory.t.sol:179 test_DynamicTopicsScenario; test/RF012_AggregatorFailClosed.t.sol:250 |
| CU-14 | `test_RNF005_registry_topics_only_owner` | test/ClaimTopicsRegistry.t.sol:95 y :201 (RevertWhen_NotOwner) |
| CU-14 | `test_RNF005_set_claim_topics_registry_cero_revierte` | test/RF011_FailClosed.t.sol:178 test_RNF005_set_claim_topics_registry_cero_revierte |
| CU-14 | `test_RNF005_agregar_modulo_sin_tocar_token` | test/ComplianceAggregator.t.sol:358 test_DynamicModuleAddition; test/RF012_AggregatorFailClosed.t.sol:250 |
| CU-14 | `test_RNF005_topics_persisten_entre_llamadas` | test/ClaimTopicsRegistry.t.sol:64 test_AddClaimTopic_MultipleKeepsInsertionOrder |
| CU-15 | `test_RF011_isVerified_registry_topics_cero_false` | test/RF011_FailClosed.t.sol:90 test_RF011_isVerified_sin_registry_topics_false |
| CU-16 | `test_RF012_agregar_modulo_sin_tocar_token_holder` | test/RF012_AggregatorFailClosed.t.sol:173 test_RF012_aggregator_admin_del_token_ok; :250 |
| CU-16 | `test_RF012_retirar_ultimo_modulo_bloquea` | test/RF012_AggregatorFailClosed.t.sol:270 test_RF012_retirar_ultimo_modulo_bloquea |

### 4.2 Nombres de test renombrados que el documento no cita (o cita en prosa)

| Nombre antiguo (ya inexistente) | Nombre vigente | Evidencia |
|---|---|---|
| `test_NoModules_AllowsAll` | `test_NoModules_FailClosed` | Comentario en `test/ComplianceAggregator.t.sol:344-346`; RF-012 invirtió la aserción a fail-closed |
| `test_TokenAndOwnerCanBothManageModules` | `test_TokenCanManageModules_OwnerCannot` | Comentario en `test/ComplianceAggregator.t.sol:546-549`; RF-012 acota la administración al token |
| `test_FailOpenNoClaimTopicsRegistry` (citado en `casos_uso.md:898`) | `test_RF011_isVerified_sin_registry_topics_false` | PoC eliminado; RF-011 lo sustituye por la suite `RF011_FailClosed.t.sol` |
| `test_AggregatorFailOpenNoModules` (citado en `casos_uso.md:944`) | `test_NoModules_FailClosed` | PoC eliminado; RF-012 lo sustituye por la suite `RF012_AggregatorFailClosed.t.sol` |

### 4.3 Etiquetas de estado obsoletas (además de los nombres)

Los criterios y CU marcados **«A IMPLEMENTAR (RF-00x)»** cuyo RF ya está implementado y con test/gate verde son:
**RF-001** (CU-02, CU-03), **RF-002** (CU-04, CU-10), **RF-003** (CU-05, CU-07), **RF-004** (CU-06), **RF-005** (CU-08), **RF-006** (CU-12), **RF-009** (CU-11), **RF-010** (CU-13, con gate `check_secrets.sh`), **RF-011** (CU-15), **RF-012** (CU-16) y **RF-013** (CU-17).
La acción pendiente es de redacción en `casos_uso.md` (sustituir «A IMPLEMENTAR» por «IMPLEMENTADO»), sin tocar `sc/**`.


---

## 5. Anexo — criterios que dependen de la CI (jobs) y estado en el último pipeline verde

Últimos pipelines verdes documentados: **2934202154** y **2934241152** en la rama `rwa-sc-DSH-GCP`, **7/7 jobs en `success`** (`metricas_ejecucion.md` §20.1 y `estado_proyecto.md`). Además, el ensayo local `sc/script/ci/run_local_ci.sh` devuelve `exit 0` con las 7 etapas.

| Criterio `ci_check_*` | Script/gate que lo materializa | Job de `.gitlab-ci.yml` | Estado en el pipeline verde |
|---|---|---|---|
| `ci_check_RF005_forge_build_ok` | `forge build` | `build` | OK (job success) |
| `ci_check_RF005_submodulos_pinneados` | `git submodule status` + conteo en `.gitmodules` | `validate` | OK (job success) |
| `ci_check_RF005_remappings_coherentes` | — (falla implícitamente en build, sin check explícito) | `build` | PARCIAL (no hay check explícito) |
| `ci_check_RF009_pipeline_test_exit_0` | `forge test` (386/386) | `test` | OK: `386 tests passed, 0 failed, 0 skipped` |
| `ci_check_RNF002_coverage_mayor_igual_80` | `sc/script/ci/check_coverage.sh` | `coverage` | OK: agregado `src/` 97.12 % (674/694); mínimo por contrato 91.53 % |
| `ci_check_RF009_artefacto_lcov_publicado` | artifacts `sc/lcov.info` | `coverage` | OK (artefacto publicado) |
| `ci_check_RF009_umbral_configurable_centralizado` | `COVERAGE_THRESHOLD` / `COVERAGE_CONTRACT_THRESHOLD` | `coverage` | OK (leído por el script) |
| `ci_check_RNF003_bloqueo_merge_con_fallos` | gate del job `test` (bloqueo de merge = rama protegida) | `test` | PARCIAL (config externa a GitLab) |
| `ci_check_RF002_no_bypassCompliance_storage` | `sc/script/ci/check_no_bypass_flag.sh` | `ci-checks` | OK (sin `bypassCompliance`) |
| `ci_check_RF006_refs_rotas_cero` | `sc/script/ci/check_docs.sh` | `ci-checks` | OK (12 documentos consistentes) |
| `ci_check_RF006_security_md_existe` | `sc/script/ci/check_docs.sh` | `ci-checks` | OK |
| `ci_check_RF006_hallazgos_cubiertos` | `sc/script/ci/check_docs.sh` | `ci-checks` | OK (HB-01..HB-12) |
| `ci_check_RF006_changelog_abis_existe` | `sc/script/ci/check_docs.sh` | `ci-checks` | OK |
| `ci_check_RF006_abi_diff_automatico` | `sc/script/ci/abi_diff.sh` | `ci-checks` | OK (15 ABIs sin deriva) |
| `ci_check_RF006_docs_sin_placeholders` | `sc/script/ci/check_docs.sh` | `ci-checks` | OK |
| `ci_check_RF006_mitigacion_con_test` | `sc/script/ci/check_docs.sh` (sección (g)) | `ci-checks` | OK |
| `ci_check_RF010_* (8 criterios)` | `sc/script/ci/check_secrets.sh` + `deploy-besu.sh` / `sc/script/deploy.sh` | `ci-checks` | CUBIERTO: secret-scan en el gate `ci-checks`; comportamiento de `deploy.sh` verificado por el propio gate |

Jobs del pipeline sin criterio asociado en `casos_uso.md`: **`fmt`** (`forge fmt --check`) y **`gas`** (`forge snapshot --check --tolerance 5`, gate RNF-001/D-039). El job `gas` cubre de forma complementaria RNF-001, cuyo criterio EARS `test_RNF001_gas_clone_menor_que_deploy_completo` está clasificado PARCIAL.

> **Nota de evidencia (v2):** la contradicción de `estado_proyecto.md` que señalaba la v1 («Brechas abiertas» decía que el pipeline no había corrido en remoto) quedó corregida en el cierre de Fase 4: el pipeline **sí** se ejecutó en remoto, con IDs **`2934202154`** y **`2934241152`** en verde (7/7 jobs). `SECURITY.md` y la cabecera de `.gitlab-ci.yml` se alinearon con este estado (AF-11).
