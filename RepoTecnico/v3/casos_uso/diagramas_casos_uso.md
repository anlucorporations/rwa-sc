# Diagramas de casos de uso — RWA v3 «Barlo Metaplace»

> **Versión:** v3.2 · **Fecha:** 2026-11-04 · **Fase:** 2
> **Fuente:** `casos_uso.md` v3.2 (29 CU, 10 actores). Todos los diagramas son **Mermaid** renderizable
> en cualquier visor. Mismos nombres de actor y de caso que el documento de casos de uso.

## 1. Diagrama de casos de uso (actores ↔ CU)

```mermaid
flowchart LR
    %% Actores
    VIS((Visitante))
    USR((Usuario))
    FIA((Fiador))
    OPE((Operador))
    EMI((Emisor))
    ADM((Admin))
    AUD((Auditor))
    ARB((Árbitro))
    SOP((Soporte))
    SIS[[Sistema]]

    subgraph META[Suite Metaplace]
        CU01[CU-01 Consultar catálogo]
        CU02[CU-02 Autenticarse SIWE]
    end
    subgraph IDENT[Suite Identity]
        CU03[CU-03 Crear identidad]
        CU04[CU-04 Solicitar claim]
        CU05[CU-05 Ver certificados]
        CU06[CU-06 Recuperar identidad]
        CU07[CU-07 Consentir fianza]
    end
    subgraph ISS[Suite Issuer]
        CU08[CU-08 Crear ISSUER]
        CU09[CU-09 Verificar documentos]
        CU10[CU-10 Emitir claim]
        CU11[CU-11 Revocar claim]
        CU12[CU-12 Tokenizar producto]
        CU13[CU-13 Tokenizar servicio]
        CU14[CU-14 Tokenizar bien]
        CU15[CU-15 Gestionar roles]
        CU16[CU-16 Configurar comisiones]
        CU17[CU-17 Panel Sistema]
        CU18[CU-18 Exportar auditoría]
        CU19[CU-19 Escalar incidencia]
    end
    subgraph TOK[Suite Token / Mercado]
        CU20[CU-20 Publicar activo]
        CU21[CU-21 Comprar]
        CU22[CU-22 Confirmar recepción]
        CU23[CU-23 Abrir disputa]
        CU24[CU-24 Resolver disputa]
        CU25[CU-25 Consumir servicio]
    end
    subgraph JOBS[Jobs de sistema]
        CU26[CU-26 Expirar reservas]
        CU27[CU-27 Purgar documentos]
        CU28[CU-28 Indexar eventos]
        CU29[CU-29 Conciliar pagos]
    end

    VIS --> CU01
    VIS --> CU02
    USR --> CU03
    USR --> CU04
    USR --> CU05
    USR --> CU06
    USR --> CU20
    USR --> CU21
    USR --> CU22
    USR --> CU23
    USR --> CU25
    FIA --> CU07
    OPE --> CU09
    EMI --> CU10
    EMI --> CU11
    EMI --> CU12
    EMI --> CU13
    EMI --> CU14
    ADM --> CU08
    ADM --> CU10
    ADM --> CU11
    ADM --> CU15
    ADM --> CU16
    ADM --> CU17
    AUD --> CU17
    AUD --> CU18
    ARB --> CU24
    SOP --> CU19
    SIS --> CU26
    SIS --> CU27
    SIS --> CU28
    SIS --> CU29

    %% Relaciones include/extend
    CU04 -.->|include| CU02
    CU21 -.->|include| CU02
    CU22 -.->|include| CU21
    CU23 -.->|extend| CU21
    CU24 -.->|include| CU23
    CU12 -.->|include| CU10
    CU20 -.->|include| CU05
```

## 2. Secuencia — Alta y certificación de Socio (CU-02/03/04/09/10)

```mermaid
sequenceDiagram
    autonumber
    actor U as Usuario
    participant W as Wallet
    participant API as API Metaplace
    participant DB as PostgreSQL
    participant OP as Operador
    participant EM as Emisor
    participant AN as Anvil (contratos)

    U->>API: GET /api/auth/nonce
    API->>DB: crear nonce (1 uso, TTL 5 min)
    API-->>U: nonce + mensaje SIWE
    U->>W: firmar mensaje
    W-->>U: firma
    U->>API: POST /api/auth/verify (firma)
    API->>API: validar firma, domain, chainId, nonce
    API-->>U: cookie httpOnly + sesión
    U->>API: POST /api/identity
    API->>DB: INSERT identities (alias, kyc_level=0)
    U->>API: POST /api/claims (ISSUER kyc-base + documentos)
    API->>API: validar MIME, tamaño, cuota; cifrar AES-256-GCM
    API->>DB: INSERT claim_requests (pending) + document_files
    OP->>API: abrir cola /emisor/verificacion
    OP->>API: marcar documentos verificados
    API->>DB: UPDATE verified_by_wallet, verified_at, status=documents_verified
    EM->>API: aprobar claim (firma EIP-712)
    API->>AN: addClaim(topic, issuer, expiry, signature, data)
    AN-->>API: tx_hash + evento ClaimAdded
    API->>DB: UPDATE claim_requests (approved, issuer_id, tx_hash)
    API-->>U: certificado vigente
```

## 3. Secuencia — Compra con escrow BRLT + NFT (CU-21/22)

```mermaid
sequenceDiagram
    autonumber
    actor C as Comprador
    participant API as API Metaplace
    participant DB as PostgreSQL
    participant MK as MarketplaceEscrow
    participant BR as BarloToken (BRLT)
    participant AN as Anvil
    participant IDX as Indexer

    C->>API: POST /api/orders (listing, quantity)
    API->>DB: INSERT orders (pending_payment, TTL 30 min, fee 5 %)
    API-->>C: orden + mensaje de firma legible
    C->>MK: firmar depósito BRLT
    MK->>BR: transferFrom(comprador → escrow)
    MK-->>API: tx_hash (leg 1)
    API->>DB: UPDATE escrow_tx_hash, status=escrowed
    Note over MK: el vendedor transfiere el activo (leg 2)
    MK->>MK: safeTransferFrom(vendedor → comprador)
    MK-->>API: tx_hash (leg 2)
    API->>DB: UPDATE escrow_asset_tx_hash, asset_transferred_at
    C->>API: POST /api/orders/{id}/confirm
    API->>DB: validar ambos tramos y estado
    MK->>BR: liberar 95 % al vendedor y 5 % a FeeCollector
    API->>DB: UPDATE orders confirmed + payments
    AN-->>IDX: eventos Transfer/OrderConfirmed
    IDX->>DB: INSERT chain_events + last_block
```

## 4. Secuencia — Tokenización de un bien (CU-14)

```mermaid
sequenceDiagram
    autonumber
    actor E as Emisor
    participant API as API Metaplace
    participant DB as PostgreSQL
    participant AF as AssetFactory
    participant NFT as AssetNFT721
    participant AN as Anvil

    E->>API: POST /api/assets (tipo good, documentos, tasación)
    API->>API: validar GARANTÍA + FIADOR verificadas y SOCIO
    API->>DB: INSERT tokens (draft) + asset_documents + token_guarantees
    E->>API: firmar acuñación (EIP-712)
    API->>AF: createAsset(requiredClaims, metadataURI)
    AF->>NFT: deploy + mint(emisor, tokenId)
    NFT-->>API: token_address + tokenId + tx_hash
    API->>DB: UPDATE tokens (minted, token_address, on_chain_token_id)
    API->>DB: audit_log asset.tokenize
    E->>API: publicar en Metaplace (CU-20)
```

## 5. Secuencia — Disputa y resolución (CU-23/24)

```mermaid
sequenceDiagram
    autonumber
    actor C as Comprador
    actor A as Árbitro
    participant API as API Metaplace
    participant DB as PostgreSQL
    participant MK as MarketplaceEscrow

    C->>API: POST /api/orders/{id}/dispute (motivo + evidencias)
    API->>DB: INSERT disputes (open) + orders.status=disputed
    API-->>A: notificación de disputa
    A->>API: GET /api/disputes/{id} (evidencias)
    A->>API: POST /api/disputes/{id}/resolve (a favor comprador)
    API->>MK: refund(orderId)
    MK-->>API: tx_hash
    API->>DB: UPDATE disputes resolved_buyer + orders refunded + payments refund
    API->>DB: audit_log dispute.resolve
    API-->>C: reembolso confirmado
```

## 6. Secuencia — Recuperación de identidad con 4-eyes (CU-06)

```mermaid
sequenceDiagram
    autonumber
    actor U as Usuario
    actor A1 as Admin 1
    actor A2 as Admin 2
    participant API as API Metaplace
    participant DB as PostgreSQL

    U->>API: POST /api/recovery (evidencia + wallet nueva)
    API->>DB: INSERT identity_recovery_requests (requested)
    A1->>API: aprobar (wallet A1)
    API->>DB: UPDATE approved_by_wallet, status=in_review
    A2->>API: aprobar (wallet A2 distinta)
    API->>DB: validar 4-eyes (A1 ≠ A2 ≠ solicitante)
    API->>DB: UPDATE identities.wallet_address = nueva, status=active
    API->>DB: audit_log recovery.approve.first / .second
    API-->>U: identidad recuperada
```

## 7. Secuencia — Jobs programados (CU-26/27/28/29)

```mermaid
sequenceDiagram
    autonumber
    participant SCH as Cloud Scheduler
    participant JOB as Cloud Run Job rwa-jobs
    participant DB as PostgreSQL
    participant IDX as rwa-indexer
    participant MON as Alertas

    SCH->>JOB: POST /internal/jobs/expire-orders (cada 5 min, OAuth)
    JOB->>DB: SELECT rwa.expire_orders()
    DB-->>JOB: n canceladas
    SCH->>JOB: POST /internal/jobs/purge-documents (diario 03:00)
    JOB->>DB: SELECT rwa.purge_expired_documents()
    DB-->>JOB: n documentos borrados
    JOB->>DB: audit_log document.purge
    SCH->>IDX: ejecutar indexer (cada 10 min)
    IDX->>DB: INSERT chain_events + update indexer_state
    JOB-->>MON: métricas y alertas (lag, fallos)
```

## 8. Máquina de estados de la orden (referencia)

```mermaid
stateDiagram-v2
    [*] --> pending_payment
    pending_payment --> escrowed : depósito BRLT
    pending_payment --> cancelled : TTL vencido
    escrowed --> confirmed : ambos tramos + confirmación
    escrowed --> cancelled : TTL / acuerdo
    escrowed --> disputed : disputa
    disputed --> confirmed : árbitro → vendedor
    disputed --> refunded : árbitro → comprador
    confirmed --> [*]
    cancelled --> [*]
    refunded --> [*]
```

---

*Diagramas v3.2 · coherentes con `casos_uso.md` y `base_datos.sql` (triggers de estado).*
