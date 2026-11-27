# Policy bundle

The Rego policies that decide access in the FAP IoT & AI once identities come from verified
credentials: who may log in, which catalogue layers and lakehouse tables a role may read, when a
DSP negotiation or transfer may proceed, and who may use AI Insight. Every package is deny by
default and decides on claims only (organisation DID, roles, purpose), as they come out of a
verified presentation or a signed token.

## Packages

| Package | Query (OPA data API) | Input | Decides |
|---|---|---|---|
| `facis.login` | `POST /v1/data/facis/login/allow` | `{org_did, roles}` | A valid organisation DID and at least one known role may log in. Asked by the guard's login provider after a verified presentation |
| `facis.participant` | `POST /v1/data/facis/participant/allow` | `{action, caller_roles, org_did}` | Issuing and revoking participant credentials require `administrator` |
| `facis.catalogue` | `POST /v1/data/facis/catalogue/allow` | `{roles, layer, purpose}` | The role may see that catalogue layer, with a declared known purpose |
| `facis.negotiation` | `POST /v1/data/facis/negotiation/permit` | `{subject, action, resource, context}` | The gate the DSP connector asks before agreeing: known participant, purpose declared and allowed, offer and dataset visible, constraints allowed |
| | `POST /v1/data/facis/negotiation/allow` | `{org_did, roles, offer_purpose, offer_id, dataset}` | The same decision, flat input |
| `facis.transfer` | `POST /v1/data/facis/transfer/allow` | `{format, roles, agreement_state, purpose}` | A transfer only on a FINALIZED agreement, with a known format, role and purpose |
| `facis.ai_insight` | `POST /v1/data/facis/ai_insight/allow` | `{roles, purpose}` | AI Insight for administrator, data_scientist and data_analyst, with the `ai_insight` purpose |
| `facis.lakehouse` | `POST /v1/data/facis/lakehouse/read` | `{roles, layer, table, columns}` | Read access per layer and table, with consumer-level columns restricted |

Each query returns a decision object `{"allow": bool, "reason": str}`. Callers read
`.result.allow`; the reason is for logs.

The negotiation subject is a DSP participant (`participantRoles`: `data_provider`,
`data_consumer`, from the participant credential). User roles never pass the negotiation gate, and
participant roles never pass the user-facing packages.

## Design rules

- **No business knowledge in the Rego.** Roles, purposes, layers, formats, agreement states and
  the DID pattern live in `bundle/facis/vocabulary/data.json` (`data.facis.vocabulary`). The
  packages read it and never redefine it. Role and purpose values follow
  [the credential schemas](../../schemas/credentials/README.md): renaming one in a single place
  silently denies access.
- **Claims are input only**, never negotiated by the client.
- **Undefined is not false.** Every check is an explicit predicate, and each package declares
  `default allow := {"allow": false, ...}`.
- **Format check before use.** The organisation DID is matched against the vocabulary's pattern
  before any claim is used downstream.
- **Provider-default roles are ignored.** Roles a token carries that are not in the vocabulary
  (for example an identity provider's `offline_access`) are filtered out, not treated as a deny.

## Run it

```bash
opa test infrastructure/opa/bundle -v              # unit tests
infrastructure/opa/check-fixtures.sh               # replay the decision fixtures (needs jq)

opa run --server --addr 127.0.0.1:8181 infrastructure/opa/bundle &
curl -s -X POST http://127.0.0.1:8181/v1/data/facis/login/allow \
  -d '{"input":{"roles":["data_analyst"],"org_did":"did:web:org-x.example"}}'
```

The CI workflow `.github/workflows/policy-bundle.yml` runs the formatting check, the unit tests and
the fixture replay on every change to this folder.

## Decision fixtures

`fixtures/` is the executable specification: at least one allow and one deny per package, plus the
edge cases (no purpose, unknown dataset, unmet constraint, restricted columns). Each file names
the query, the input and the expected verdict. Extend them, never weaken them: the deny fixtures
are the ones that matter. The unit tests mirror the fixtures and add more edge cases (invalid DID,
unknown role, purpose or layer, non-final agreement).

## Where it runs

In a deployment the bundle is served by the policy engine that the DSP connector flows, the guard's
login provider and the AI Insight service query over the OPA data API. Wiring those callers is part
of their own components, not of this bundle.
