# Matriz de trazabilidad — criterio de aceptación → prueba

> **Proyecto:** RWA / `rwa-sc` · **Fase 4 (Pruebas)** · **Fecha:** 2026-10-10
> **Fuente de criterios:** `RepoTecnico/casos_uso/casos_uso.md` v1.3 (17 CU · 92 Gherkin + 50 EARS = **142 criterios**).
> **Fuentes de prueba:** `rwa-sc/sc/test/**` (18 archivos, **353 tests**) y `rwa-sc/sc/script/ci/**` + `rwa-sc/.gitlab-ci.yml` (7 jobs).
> **Alcance de este informe:** solo lectura sobre `rwa-sc/sc/**`; el único archivo escrito es este.

---

## 1. Resumen ejecutivo

| Estado | Criterios | % |
|---|---:|---:|
| **CUBIERTO** | 111 | 78.2 % |
| **PARCIAL** | 22 | 15.5 % |
| **FALTA** | 9 | 6.3 % |
| **N/A** | 0 | 0.0 % |
| **TOTAL** | **142** | **100 %** |

**Totales verificados por comando** (no a ojo):

- Criterios extraídos del documento: `grep -cE '^([0-9]+\. |- )\`(test_|ci_check_)' casos_uso.md` → **142** (92 ítems numerados + 50 viñetas EARS).
- Tests existentes: `grep -rhoE 'function[[:space:]]+test[A-Za-z0-9_]*' sc/test --include='*.sol' | wc -l` → **353** funciones `test*` en **18** archivos.
- Nombres de test citados literalmente en el documento que **no existen** hoy: **67** `test_*` (ver §4).
- Los 24 nombres `ci_check_*` no son funciones de test: se resuelven contra scripts/gates y jobs del pipeline.

> **Nota de concurrencia (estado observado al cerrar el análisis):** durante esta Fase 4 apareció, por un proceso paralelo, el directorio no versionado `sc/test/invariant/` (2 archivos de invariantes + 3 handlers, con 10 funciones `invariant_*`) y una modificación de `sc/foundry.toml`. La línea base de esta matriz es la indicada (18 archivos, 353 tests `test_*`); las invariantes **no** modifican la clasificación de los 142 criterios (no cubren ninguno de los 9 FALTA, que son criterios nominales de aceptación). Este informe es de solo lectura: no ha tocado `sc/**` ni `casos_uso.md`.

### Veredicto

- **Cobertura real alta pero con etiquetas de estado obsoletas.** **111/142 (78,2 %)** criterios están CUBIERTOS por un test o gate real; **22 (15,5 %)** quedan PARCIALES y **9 (6,3 %)** FALTA. N/A = 0.
- **El código adelantó al documento.** RF-001, RF-002, RF-003, RF-004, RF-009, RF-011, RF-012 y RF-013 están **implementados y probados** (suites `RF003_ERC165`, `RF011_FailClosed`, `RF012_AggregatorFailClosed`, `RF013_ClaimLifecycle`, `TokenLimits`, `TokenReentrancy`, `IdentityCloneable`), aunque `casos_uso.md` sigue rotulándolos *«A IMPLEMENTAR»*. RF-005 y RF-006 están implementados salvo flecos concretos (umbral de gas y `ci_check_RF006_mitigacion_con_test`). **RF-010** está implementado en `sc/script/deploy.sh`, pero **sin ninguna verificación automatizada** (no hay job de CI ni test shell): por eso sus 8 criterios son PARCIAL/FALTA.
- **El desfase principal es de nombres, no de comportamiento:** 67 criterios citan un `test_*` que no existe con ese nombre; muchos están cubiertos por un test equivalente con otra convención (las suites de registries/factories usan `test_<Acción>` en lugar de `test_RF00X_...`).
- **Los huecos reales se concentran en CU-13 (RF-010):** no existe ningún gate de CI; 7 de sus 8 criterios son PARCIALES y el `secret-scan` es FALTA. También hay 2 FALTA en CU-08, 2 en CU-14 y 1 en CU-01, CU-10, CU-12 y CU-16.
- **Veredicto de fase:** la matriz se puede entregar; **no bloquea el cierre** pero **sí exige dos acciones**: (a) corregir en `casos_uso.md` los nombres obsoletos y las etiquetas «A IMPLEMENTAR» ya materializadas; (b) cerrar los 9 FALTA con las pruebas mínimas de §3. Debe revisarse además la contradicción de `estado_proyecto.md`: la sección «Brechas abiertas» dice que el pipeline no ha corrido en remoto mientras la sección «Pipeline en GitLab (cerrado)» documenta el pipeline **2934202154 verde (7/7)**.

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
| 7 | L184 `test_RF001_registries_owner_tras_renuncia` | Gherkin | - | **FALTA** | No existe test de renounceOwnership en ninguna suite (grep -rn 'renounceOwnership' sc/test -> 0) |
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
| 5 | L547 `test_RF005_initialization_implementacion_bloqueada` | Gherkin | - | **FALTA** | Ningun test llama initialize() sobre factory.implementation() (grep 'InvalidInitialization' en test -> 0) |
| 6 | L553 `test_RNF001_gas_clone_menor_que_deploy_completo` | EARS | test/TokenCloneFactory.t.sol:132 test_GasSavings | **PARCIAL** | El test real mide ahorro >=45% frente al despliegue equivalente, no el '<10%' que fija el criterio |
| 7 | L554 `test_RF005_implementacion_unica_por_factory` | EARS | test/TokenCloneFactory.t.sol:27 test_Deployment | **PARCIAL** | Solo comprueba implementation != 0; no verifica unicidad/inmutabilidad |
| 8 | L555 `test_RF005_clones_independientes` | EARS | test/TokenCloneFactory.t.sol:187 test_IndependentClones | **CUBIERTO** | Cubierto con nombre distinto |
| 9 | L556 `test_RF005_no_storage_muerto_tokenName` | EARS | - | **FALTA** | _tokenName/_tokenSymbol siguen en src/TokenCloneable.sol:47-48 (asignados en :103) y name()/symbol() vienen de ERC20Upgradeable; no hay test (grep en test -> 0) |

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
| 12 | L695 `test_RF002_transfer_from_sin_allowance_revierte` | EARS | - | **FALTA** | Sin test de allowance insuficiente (grep 'InsufficientAllowance' en test -> 0) |

### CU-11 — Compilar y ejecutar la suite de tests en CI con umbral de cobertura

| # | Criterio (casos_uso.md) | Tipo | Prueba que lo verifica | Estado | Nota |
|---|---|---|---|---|---|
| 1 | L721 `ci_check_RF005_forge_build_ok` | Gherkin | sc/.gitlab-ci.yml job build (stage build); pipeline 2934202154 success | **CUBIERTO** | Gate de CI real |
| 2 | L725 `ci_check_RF009_pipeline_test_exit_0` | Gherkin | sc/.gitlab-ci.yml job test (stage test); 353/353 en verde | **CUBIERTO** | Gate de CI real |
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
| 6 | L788 `ci_check_RF006_mitigacion_con_test` | EARS | - | **FALTA** | check_docs.sh no comprueba que las mitigaciones de SECURITY.md referencien un test_*/ci_check_* |
| 7 | L789 `ci_check_RF006_docs_sin_placeholders` | EARS | sc/script/ci/check_docs.sh:95-103 | **CUBIERTO** | Gate real |

### CU-13 — Gestionar secretos de despliegue sin material en repositorios

| # | Criterio (casos_uso.md) | Tipo | Prueba que lo verifica | Estado | Nota |
|---|---|---|---|---|---|
| 1 | L814 `ci_check_RF010_script_sin_keys_json` | Gherkin | deploy-besu.sh y sc/script/deploy.sh | **PARCIAL** | La propiedad se cumple (grep 'keys.json' -> 0), pero no hay gate de CI que la verifique |
| 2 | L818 `ci_check_RF010_script_usa_env` | Gherkin | sc/script/deploy.sh:98-102 | **PARCIAL** | Lee la clave del entorno; sin gate de CI |
| 3 | L822 `ci_check_RF010_secret_scan_sin_hallazgos` | Gherkin | - | **FALTA** | No hay gitleaks/trufflehog ni job de secret-scan en .gitlab-ci.yml |
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
| 4 | L877 `test_RNF005_cambio_topics_afecta_isVerified` | Gherkin | - | **FALTA** | No hay test de regresion que anada un topic a un token con wallet ya verificada y compruebe isVerified false |
| 5 | L881 `test_RNF005_nueva_regla_sin_redeploy_token` | Gherkin | test/ClaimTopicsRegistryCloneFactory.t.sol:179 test_DynamicTopicsScenario; test/RF012_AggregatorFailClosed.t.sol:250 | **CUBIERTO** | Cubierto con nombre distinto |
| 6 | L887 `test_RNF005_registry_topics_only_owner` | EARS | test/ClaimTopicsRegistry.t.sol:95 y :201 (RevertWhen_NotOwner) | **CUBIERTO** | Cubierto con nombre distinto |
| 7 | L888 `test_RNF005_set_claim_topics_registry_cero_revierte` | EARS | - | **FALTA** | Sin test de setClaimTopicsRegistry(address(0)) (grep 'Invalid registry address' en test -> 0) |
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
| 8 | L986 `test_RF012_retirar_ultimo_modulo_bloquea` | EARS | - | **FALTA** | No hay test que retire el ultimo modulo activo y compruebe canTransfer false |

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

## 3. Criterios FALTA/PARCIAL y prueba mínima sugerida

Prioridad: **P1** = hueco funcional real o criterio contradicho por el código; **P2** = cobertura indirecta o debilitada; **P3** = deuda de verificación (CI/documentación).

### 3.1 FALTA (9)

| Prioridad | CU | Criterio | Por qué falta | Prueba mínima sugerida |
|---|---|---|---|---|
| P1 | CU-01 | `test_RF001_registries_owner_tras_renuncia` | No existe test de renounceOwnership en ninguna suite (grep -rn 'renounceOwnership' sc/test -> 0) | Anadir `test_RF001_registries_owner_tras_renuncia`: `renounceOwnership()` en `TrustedIssuersRegistry`/`IdentityRegistry` y, con `vm.prank`, comprobar que `addTrustedIssuer`, `removeTrustedIssuer`, `updateIssuerClaimTopics` (y las equivalentes de identidad) revierten con `OwnableUnauthorizedAccount` y no alteran el estado. |
| P1 | CU-08 | `test_RF005_initialization_implementacion_bloqueada` | Ningun test llama initialize() sobre factory.implementation() (grep 'InvalidInitialization' en test -> 0) | `vm.expectRevert(InvalidInitialization.selector); TokenCloneable(factory.implementation()).initialize("X","X",18,admin)`. |
| P1 | CU-08 | `test_RF005_no_storage_muerto_tokenName` | _tokenName/_tokenSymbol siguen en src/TokenCloneable.sol:47-48 (asignados en :103) y name()/symbol() vienen de ERC20Upgradeable; no hay test (grep en test -> 0) | Eliminar `_tokenName`/`_tokenSymbol` de `TokenCloneable` (ya no se usan: `name()`/`symbol()` vienen de `ERC20Upgradeable`) y anadir un test que inspeccione `out/TokenCloneable.sol/TokenCloneable.json` y afirme que el `storageLayout` no contiene `_tokenName` (analogo a `test_RF002_storage_layout_sin_bypassCompliance`). |
| P1 | CU-10 | `test_RF002_transfer_from_sin_allowance_revierte` | Sin test de allowance insuficiente (grep 'InsufficientAllowance' en test -> 0) | `vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, ...)); token.transferFrom(user1, user2, 1)` con allowance 0, y comprobar que ningun modulo recibe `transferred`. |
| P3 | CU-12 | `ci_check_RF006_mitigacion_con_test` | check_docs.sh no comprueba que las mitigaciones de SECURITY.md referencien un test_*/ci_check_* | Extender `check_docs.sh`: parsear las filas de mitigacion de `SECURITY.md`, extraer la referencia `test_*`/`ci_check_*` y fallar si la funcion no existe en `sc/test/**` ni en `sc/script/ci/**`. |
| P2 | CU-13 | `ci_check_RF010_secret_scan_sin_hallazgos` | No hay gitleaks/trufflehog ni job de secret-scan en .gitlab-ci.yml | Anadir un job `secret-scan` (gitleaks o trufflehog) al pipeline, o un `sc/script/ci/check_secrets.sh` que falle ante `0x`+64 hex o `private_key`/`mnemonic` en el arbol versionado; es el unico criterio RF-010 sin ningun soporte. |
| P1 | CU-14 | `test_RNF005_cambio_topics_afecta_isVerified` | No hay test de regresion que anada un topic a un token con wallet ya verificada y compruebe isVerified false | Test de regresion: token con topics `[1]` y wallet verificada; `addClaimTopic(7)` y comprobar `isVerified(wallet)==false` sin cambios de balance. |
| P1 | CU-14 | `test_RNF005_set_claim_topics_registry_cero_revierte` | Sin test de setClaimTopicsRegistry(address(0)) (grep 'Invalid registry address' en test -> 0) | `vm.expectRevert(bytes("Invalid registry address")); token.setClaimTopicsRegistry(address(0))`. |
| P1 | CU-16 | `test_RF012_retirar_ultimo_modulo_bloquea` | No hay test que retire el ultimo modulo activo y compruebe canTransfer false | Anadir un modulo con `addModuleThroughAggregator`, retirarlo con `removeModuleThroughAggregator` y comprobar que `aggregator.canTransfer(...)==false` (y que `mint`/`transfer` revierten `"Mint not compliant"`). |

### 3.2 PARCIAL (22)

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
| CU-01 | `test_RF001_registries_owner_tras_renuncia` | _sin reemplazo (FALTA)_ |
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
| CU-08 | `test_RF005_initialization_implementacion_bloqueada` | _sin reemplazo (FALTA)_ |
| CU-08 | `test_RNF001_gas_clone_menor_que_deploy_completo` | PARCIAL: test/TokenCloneFactory.t.sol:132 test_GasSavings |
| CU-08 | `test_RF005_implementacion_unica_por_factory` | PARCIAL: test/TokenCloneFactory.t.sol:27 test_Deployment |
| CU-08 | `test_RF005_clones_independientes` | test/TokenCloneFactory.t.sol:187 test_IndependentClones |
| CU-08 | `test_RF005_no_storage_muerto_tokenName` | _sin reemplazo (FALTA)_ |
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
| CU-10 | `test_RF002_transfer_from_sin_allowance_revierte` | _sin reemplazo (FALTA)_ |
| CU-14 | `test_RNF005_addClaimTopic_ok` | test/ClaimTopicsRegistry.t.sol:52 test_AddClaimTopic |
| CU-14 | `test_RNF005_addClaimTopic_duplicado_revierte` | test/ClaimTopicsRegistry.t.sol:88 test_AddClaimTopic_RevertWhen_Duplicate |
| CU-14 | `test_RNF005_removeClaimTopic_swap_and_pop` | test/ClaimTopicsRegistry.t.sol:118 test_RemoveClaimTopic_FirstSwapsLast |
| CU-14 | `test_RNF005_cambio_topics_afecta_isVerified` | _sin reemplazo (FALTA)_ |
| CU-14 | `test_RNF005_nueva_regla_sin_redeploy_token` | test/ClaimTopicsRegistryCloneFactory.t.sol:179 test_DynamicTopicsScenario; test/RF012_AggregatorFailClosed.t.sol:250 |
| CU-14 | `test_RNF005_registry_topics_only_owner` | test/ClaimTopicsRegistry.t.sol:95 y :201 (RevertWhen_NotOwner) |
| CU-14 | `test_RNF005_set_claim_topics_registry_cero_revierte` | _sin reemplazo (FALTA)_ |
| CU-14 | `test_RNF005_agregar_modulo_sin_tocar_token` | test/ComplianceAggregator.t.sol:358 test_DynamicModuleAddition; test/RF012_AggregatorFailClosed.t.sol:250 |
| CU-14 | `test_RNF005_topics_persisten_entre_llamadas` | test/ClaimTopicsRegistry.t.sol:64 test_AddClaimTopic_MultipleKeepsInsertionOrder |
| CU-15 | `test_RF011_isVerified_registry_topics_cero_false` | test/RF011_FailClosed.t.sol:90 test_RF011_isVerified_sin_registry_topics_false |
| CU-16 | `test_RF012_agregar_modulo_sin_tocar_token_holder` | test/RF012_AggregatorFailClosed.t.sol:173 test_RF012_aggregator_admin_del_token_ok; :250 |
| CU-16 | `test_RF012_retirar_ultimo_modulo_bloquea` | _sin reemplazo (FALTA)_ |

### 4.2 Nombres de test renombrados que el documento no cita (o cita en prosa)

| Nombre antiguo (ya inexistente) | Nombre vigente | Evidencia |
|---|---|---|
| `test_NoModules_AllowsAll` | `test_NoModules_FailClosed` | Comentario en `test/ComplianceAggregator.t.sol:344-346`; RF-012 invirtió la aserción a fail-closed |
| `test_TokenAndOwnerCanBothManageModules` | `test_TokenCanManageModules_OwnerCannot` | Comentario en `test/ComplianceAggregator.t.sol:546-549`; RF-012 acota la administración al token |
| `test_FailOpenNoClaimTopicsRegistry` (citado en `casos_uso.md:898`) | `test_RF011_isVerified_sin_registry_topics_false` | PoC eliminado; RF-011 lo sustituye por la suite `RF011_FailClosed.t.sol` |
| `test_AggregatorFailOpenNoModules` (citado en `casos_uso.md:944`) | `test_NoModules_FailClosed` | PoC eliminado; RF-012 lo sustituye por la suite `RF012_AggregatorFailClosed.t.sol` |

### 4.3 Etiquetas de estado obsoletas (además de los nombres)

Los criterios y CU marcados **«A IMPLEMENTAR (RF-00x)»** cuyo RF ya está implementado y con test/gate verde son:
**RF-001** (CU-02, CU-03), **RF-002** (CU-04, CU-10), **RF-003** (CU-05, CU-07), **RF-004** (CU-06), **RF-009** (CU-11), **RF-011** (CU-15), **RF-012** (CU-16) y **RF-013** (CU-17).
**RF-005** y **RF-006** están implementados salvo los flecos señalados en §3. **RF-010** está implementado en el script de despliegue, pero sus criterios siguen sin verificación automatizada: la etiqueta «A IMPLEMENTAR» debe sustituirse por «IMPLEMENTADO (sin gate de CI)» y crearse el gate (§3). La corrección debe hacerse en el cierre de la fase sin tocar `sc/**`.


---

## 5. Anexo — criterios que dependen de la CI (jobs) y estado en el último pipeline verde

Último pipeline verde documentado: **2934202154** en la rama `rwa-sc-DSH-GCP`, **7/7 jobs en `success`** (`metricas_ejecucion.md` §20.1 y `estado_proyecto.md`). Además, el ensayo local `sc/script/ci/run_local_ci.sh` devuelve `exit 0` con las 7 etapas.

| Criterio `ci_check_*` | Script/gate que lo materializa | Job de `.gitlab-ci.yml` | Estado en el pipeline verde |
|---|---|---|---|
| `ci_check_RF005_forge_build_ok` | `forge build` | `build` | OK (job success) |
| `ci_check_RF005_submodulos_pinneados` | `git submodule status` + conteo en `.gitmodules` | `validate` | OK (job success) |
| `ci_check_RF005_remappings_coherentes` | — (falla implícitamente en build, sin check explícito) | `build` | PARCIAL (no hay check explícito) |
| `ci_check_RF009_pipeline_test_exit_0` | `forge test` (353/353) | `test` | OK: `353 tests passed, 0 failed, 0 skipped` |
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
| `ci_check_RF006_mitigacion_con_test` | — (no implementado) | — | FALTA |
| `ci_check_RF010_* (8 criterios)` | `deploy-besu.sh` / `sc/script/deploy.sh` (comportamiento) | — (ningún job) | PARCIAL/FALTA: el pipeline no tiene job RF-010; no hay secret-scan |

Jobs del pipeline sin criterio asociado en `casos_uso.md`: **`fmt`** (`forge fmt --check`) y **`gas`** (`forge snapshot --check --tolerance 5`, gate RNF-001/D-039). El job `gas` cubre de forma complementaria RNF-001, cuyo criterio EARS `test_RNF001_gas_clone_menor_que_deploy_completo` está clasificado PARCIAL.

> **Nota de evidencia:** `estado_proyecto.md` mantiene una contradicción interna — «Brechas abiertas» afirma que el pipeline «falta por ejecutar en remoto» mientras «Pipeline en GitLab (cerrado)» documenta el pipeline 2934202154 en verde. La evidencia de `metricas_ejecucion.md` §20.1 (tabla de 7 jobs con duración y artefactos) respalda la segunda; se recomienda corregir la brecha en el cierre de fase.
