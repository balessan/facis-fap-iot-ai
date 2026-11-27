# Identity and access: overview and flows

Companion to the [target architecture](icam-target-architecture.md). It shows the whole picture and the sequence of each flow, F0 to F8. The flow numbers are the labels used in the overview.

Every diagram has an editable source in [`diagrams/`](diagrams/README.md): the overview for draw.io, each sequence for sequencediagram.org. The Mermaid copies below render on GitHub and must be kept in step with those sources.

## Overview

![Identity overview: zones, guard, DSP connector, W-Stack and data lake](diagrams/icam-overview.svg)

Editable source: [`diagrams/icam-overview.drawio`](diagrams/icam-overview.drawio).

| Zone | Contents |
|---|---|
| Outside | Users with their browser or smartphone, other participants' DSP connectors |
| FAP deployment | The guard, the DSP connector with its identity steps, AI Insight |
| Federation trust services | OCM W-Stack (issuer, verifier, status list, connector tenant, NATS, crypto provider), wallets, the policy engine. Keycloak is no longer on the login path |
| Data lake | Trino and Kafka, reached by the connector for transfers and by AI Insight for queries |

Trust boundaries:

- **TB1, Internet to the federation services:** only the public routes (OpenID4VCI, OpenID4VP, `did:web`, well-known documents, status list).
- **TB2, Internet to the FAP:** the DSP endpoints, where every request carries a verified presentation (F4), and the web applications, behind the guard (F3).
- **TB3, FAP to the W-Stack internal APIs:** only the listed NATS subjects and REST routes. These APIs don't authenticate callers, so default-deny network policies and NATS ACLs are the control.

## F0. Deployment with the Builder nodes

The Easy Stack Builder nodes deploy the trust services; their outputs configure the FAP deployment, the guard included, with no manual copying. The issuer key and the connector key are created in the crypto provider, and the connector's `did:web` is published.

```mermaid
sequenceDiagram
  autonumber
  participant DEP as FAP deployment flow<br/>(ORCE)
  participant OCM as ESB OCM-WStack<br/>Builder node
  participant PCM as ESB PCM<br/>Builder node
  participant CRY as Crypto provider<br/>(OpenBao)
  participant TEN as Connector tenant<br/>(W-Stack)
  participant SEC as Secret store<br/>(OpenBao, ESO)
  participant FAP as FAP Helm releases<br/>(guard included)
  DEP->>OCM: run (instance name, domain)
  OCM->>CRY: create the issuer key
  OCM-->>DEP: W-Stack URLs, client secret, status
  opt PCM Cloud available
    DEP->>PCM: run (OCM instance name)
    PCM-->>DEP: PCM URL, issuer id, status
  end
  DEP->>TEN: install the connector tenant
  TEN->>CRY: create the connector key
  TEN-->>DEP: connector did:web published
  DEP->>SEC: store the client secrets
  DEP->>FAP: helm upgrade --install (URLs from the node outputs)
  FAP->>FAP: guard registers the web applications as OAuth2 clients
  Note over DEP,FAP: A second run needs no manual input and creates no duplicates
```

Editable source: [`diagrams/sequences/f0-deployment.txt`](diagrams/sequences/f0-deployment.txt)

## F1. Organisation credential

The DSP connector receives its participant credential from the federation issuer over OpenID4VCI (pre-authorized code), into its W-Stack tenant. The issuing plugin supplies the claims and registers the credential in the status list.

```mermaid
sequenceDiagram
  autonumber
  participant OP as Federation operator<br/>(ORCE admin flow)
  participant ISS as W-Stack issuer
  participant PAB as Pre-authorization<br/>bridge
  participant PLG as Issuing plugin<br/>(DSP connector)
  participant SL as Status list
  participant RET as Connector tenant<br/>(retrieval)
  participant CRY as Crypto provider<br/>(connector key)
  participant STO as Connector tenant<br/>(storage)
  OP->>ISS: credential offer (connector DID, participant credential type)
  ISS-->>OP: offer URI and pre-authorized code
  OP->>RET: accept the offer
  RET->>ISS: issuer metadata (well-known)
  RET->>PAB: token request (pre-authorized code)
  PAB-->>RET: access token, c_nonce
  RET->>CRY: sign the proof JWT
  CRY-->>RET: proof JWT
  RET->>ISS: credential request (proof)
  ISS->>PLG: issue callback
  PLG->>SL: create a status entry
  SL-->>PLG: status URL and index
  PLG-->>ISS: claims (legal name, roles, trust framework, status)
  ISS-->>RET: signed credential (jwt_vc_json)
  RET->>STO: store the credential
```

Editable source: [`diagrams/sequences/f1-organisation-credential.txt`](diagrams/sequences/f1-organisation-credential.txt)

## F2. Personal credential

An administrator issues a role credential to a user's wallet over OpenID4VCI. The claims come from the onboarding record. The credential can be re-issued and revoked.

```mermaid
sequenceDiagram
  autonumber
  participant A as Administrator
  participant ORCE as FAP admin flow<br/>(ORCE)
  participant ISS as W-Stack issuer
  participant PAB as Pre-authorization<br/>bridge
  participant PLG as Issuing plugin
  participant SL as Status list
  participant W as Wallet<br/>(PCM Cloud, mobile or other)
  A->>ORCE: issue a role credential to a user (claims from the onboarding record)
  ORCE->>ISS: credential offer (role credential type)
  ISS-->>ORCE: offer URI and pre-authorized code
  ORCE-->>A: QR code or link, the code shown once
  A-->>W: the user scans the QR code or opens the link
  W->>ISS: issuer metadata (well-known)
  W->>PAB: token request (pre-authorized code)
  PAB-->>W: access token, c_nonce
  W->>ISS: credential request (proof with the holder key)
  ISS->>PLG: issue callback
  PLG->>SL: create a status entry
  SL-->>PLG: status URL and index
  PLG-->>ISS: claims (name, email, org_did, roles, purposes, status)
  ISS-->>W: signed credential (jwt_vc_json)
```

Editable source: [`diagrams/sequences/f2-personal-credential.txt`](diagrams/sequences/f2-personal-credential.txt)

## F3. Wallet login through the guard

Any FAP web application sends the user to the guard. The login provider asks the W-Stack verifier for a presentation, shows it as a QR code for a mobile wallet or redirects to a web wallet, applies the login policy, and lets the authorization server issue the tokens. Rules in [the target architecture, §4](icam-target-architecture.md#4-person-login).

```mermaid
sequenceDiagram
  autonumber
  participant U as User (browser)
  participant APP as Web application
  participant AZ as Guard: authorization server
  participant LP as Guard: login provider
  participant CVS as W-Stack verifier
  participant POL as Policy engine
  participant W as Wallet
  U->>APP: open the application
  APP->>AZ: authorization request (code + PKCE)
  AZ->>LP: redirect with login_challenge
  LP->>LP: login attempt (state, nonce, 5 min, single use)
  LP->>CVS: create a presentation request (role credential, state)
  CVS-->>LP: request link (openid4vp scheme)
  alt mobile wallet
    LP-->>U: login page with the QR code (or a deep link on the same device)
    U->>W: scan the QR code or open the link
  else web wallet (PCM Cloud or another)
    LP-->>U: redirect to the selected web wallet, carrying the request
    U->>W: review and approve the request in the web wallet
  end
  W->>CVS: presentation (direct_post, DCQL)
  LP->>CVS: read the result for the state
  CVS-->>LP: verified claims, holder binding, status
  LP->>POL: login policy
  POL-->>LP: allow or deny
  LP->>AZ: accept login and consent (subject, claims)
  AZ-->>APP: authorization code, then tokens
  APP->>APP: call its APIs with the access token
```

Editable source: [`diagrams/sequences/f3-wallet-login.txt`](diagrams/sequences/f3-wallet-login.txt)

## F4. DSP inbound check

A counterparty's DSP request carries a presentation. The connector checks it, fails closed, logs the result, and asks the policy engine before any agreement or transfer.

```mermaid
sequenceDiagram
  autonumber
  participant CP as Counterparty<br/>connector
  participant VER as iam.verify<br/>(DSP connector)
  participant DID as did:web<br/>resolution
  participant CRY as W-Stack<br/>crypto provider
  participant SL as Status list
  participant POL as Policy engine
  participant DB as Negotiation state<br/>(Postgres)
  CP->>VER: DSP request with a Bearer VP-JWT
  VER->>VER: audience, expiry, nonce, jti not replayed
  VER->>DID: resolve the holder and issuer DIDs
  VER->>CRY: verify the presentation and the credential
  CRY-->>VER: signature and holder binding valid
  VER->>SL: status list (cached at most 5 min)
  VER->>VER: issuer on the trusted-issuer list
  VER->>POL: participant and negotiation policies
  POL-->>VER: allow, or deny with a reason
  VER->>DB: decision record
  VER-->>CP: agreement, or 401, 403 or TERMINATED with a reason
  Note over CP,DB: Fail closed: a failed or unreachable check gives 401, and the decision is logged
```

Editable source: [`diagrams/sequences/f4-dsp-inbound.txt`](diagrams/sequences/f4-dsp-inbound.txt)

## F5. DSP outbound presentation

The connector takes its credential from its tenant, has the crypto provider sign a presentation for this provider, and attaches it to its DSP requests.

```mermaid
sequenceDiagram
  autonumber
  participant DSP as DSP connector<br/>(consumer flow)
  participant ISS as iam.issue<br/>(DSP connector)
  participant STO as Connector tenant<br/>(storage)
  participant CRY as Crypto provider<br/>(connector key in OpenBao)
  participant P as Counterparty<br/>provider
  DSP->>ISS: presentation needed for this provider
  ISS->>STO: DCQL query for the participant credential
  STO-->>ISS: credential (jwt_vc_json)
  ISS->>CRY: sign a presentation (audience = provider, nonce, 5 min expiry)
  CRY-->>ISS: signed VP-JWT
  ISS-->>DSP: Bearer token
  DSP->>P: DSP request with the Bearer VP-JWT
  Note over ISS,CRY: No private key in the connector: the crypto provider signs with the connector key
```

Editable source: [`diagrams/sequences/f5-dsp-outbound.txt`](diagrams/sequences/f5-dsp-outbound.txt)

## F6. Revocation

An operator revokes a credential. The next DSP check and the next wallet login fail, within 5 minutes.

```mermaid
sequenceDiagram
  autonumber
  participant ADM as Operator
  participant AF as FAP admin flow
  participant SL as Status list
  participant CP as Counterparty<br/>connector
  participant VER as iam.verify<br/>(DSP connector)
  participant U as User with a wallet
  participant G as Guard<br/>(login provider)
  participant CVS as W-Stack verifier
  ADM->>AF: revoke a credential (participant, person or service)
  AF->>SL: revoke the status entry
  SL-->>AF: revoked
  CP->>VER: next DSP request with a VP
  VER->>SL: status list (cached at most 5 min)
  VER-->>CP: 401, credential revoked
  Note over U,G: Wallet-login tokens live 5 min, with no offline refresh
  U->>G: next login, presenting the revoked credential
  G->>CVS: read the result
  CVS-->>G: status revoked
  G-->>U: login refused
```

Editable source: [`diagrams/sequences/f6-revocation.txt`](diagrams/sequences/f6-revocation.txt)

## F7. Data and AI access

AI Insight checks the user's guard access token, the policy engine decides on role, organisation and purpose, and Trino is queried on the permitted columns only.

```mermaid
sequenceDiagram
  autonumber
  participant U as User
  participant UI as AI Insight UI
  participant AIS as AI Insight service
  participant G as Guard<br/>(authorization server)
  participant POL as Policy engine
  participant TR as Trino<br/>(data lake)
  U->>UI: question or dashboard request
  UI->>AIS: API call with the user's access token
  AIS->>G: JWKS (cached): check signature and expiry
  AIS->>POL: AI Insight and lakehouse policies (claims, table, columns)
  POL-->>AIS: allow with the permitted columns, or deny
  AIS->>TR: query on the permitted columns only
  TR-->>AIS: rows
  AIS->>AIS: purpose and prompt-volume rules
  AIS-->>UI: answer, or 403 with a reason
  Note over AIS,POL: Every decision is logged with a correlation id and the policy version
```

Editable source: [`diagrams/sequences/f7-data-and-ai-access.txt`](diagrams/sequences/f7-data-and-ai-access.txt)

## F8. Machine identity (design option)

Services obtain a short-lived token from the guard instead of using static secrets. Which of the two ways is used is an open point of the target architecture (§10).

```mermaid
sequenceDiagram
  autonumber
  participant AF as FAP admin flow
  participant ISS as W-Stack issuer
  participant STO as Organisation tenant<br/>(storage)
  participant SVC as Service<br/>(NiFi, Spark, AI processing)
  participant CRY as Crypto provider
  participant G as Guard<br/>(authorization server)
  participant API as Trino or<br/>another data API
  alt presentation exchanged for a token
    AF->>ISS: offer a service credential (service DID)
    ISS-->>STO: service credential stored
    SVC->>STO: load its credential
    SVC->>CRY: sign a presentation (audience = guard token endpoint)
    CRY-->>SVC: signed VP
    SVC->>G: token request with the VP (JWT bearer grant)
    G->>G: verify the VP, status, issuer and policy
  else client credentials with DPoP
    SVC->>G: client credentials grant with a DPoP proof
  end
  G-->>SVC: short-lived access token (sub = service DID or client id)
  SVC->>API: call with that token, no static secret
  Note over AF,API: Design option: how machine clients obtain tokens is still open
```

Editable source: [`diagrams/sequences/f8-machine-identity.txt`](diagrams/sequences/f8-machine-identity.txt)
