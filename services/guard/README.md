# Guard: wallet login for the web applications

The guard is the OAuth2 / OpenID Connect authorization server of the FAP IoT & AI web
applications. A user logs in by presenting a role credential from a wallet (OID4VP); the W-Stack
credential verifier checks the presentation, the policy engine decides, and the guard issues
short-lived tokens with the verified claims. See
[the target architecture](../../docs/architecture/icam-target-architecture.md), §4 and §5.

| Part | What it is | Where |
|---|---|---|
| Authorization server | Ory Hydra v26.2.0 and its PostgreSQL: OAuth2 endpoints, token signing, JWKS | `helm/facis-guard` |
| Login and consent provider | ORCE flow: login page, presentation request, checks, login decision, consent | `orce/flows/facis-guard-login.json` |
| Policy engine | OPA serving `infrastructure/opa/bundle` (package `facis.login`) plus the deployment data | `helm/facis-guard` |
| Local test setup | Stub verifier, edge proxy, install script, end-to-end check | `local/` |

## How a login works

1. The application sends the browser to the authorization server (`/oauth2/auth`, code + PKCE),
   which sends it to the login provider (`/guard/login?login_challenge=...`).
2. The login provider checks that the application is a first-party client, asks the verifier for
   a presentation request and shows it: a QR code for a mobile wallet, a link for a wallet on the
   same device, and a button per configured web wallet. The attempt is single use and expires
   after 5 minutes.
3. The page polls `/guard/login/status`. The login provider reads the presentation the verifier
   stored for this request, never what the wallet answered, and checks:
   - the record is verified and belongs to this request, and answers its DCQL query only;
   - the nonce and the audience are this request's;
   - holder binding: the credential subject is the presenter;
   - the credential is valid now, and its status list (on an allowed origin) shows it is not
     revoked.
4. The policy engine decides (`facis.login`): the issuer is trusted and vouches for the
   organisation, and a disclosed role is allowed for the application.
5. The login is accepted with the holder DID as subject. Consent is given without a page for the
   first-party applications: `org_did`, `roles` and `purpose` go into the access token and the ID
   token, `name` and `email` into the ID token only. Tokens live 5 minutes; no refresh token.

Refusals caused by the presentation count as failures: five within 15 minutes lock the client
address and the holder out for 15 minutes. Failures of the platform (verifier, status list or
policy engine unavailable) do not count. `GET /guard/admin/lockouts` lists the lockouts and
`DELETE /guard/admin/lockouts?key=...` lifts one (bearer admin token, inside the cluster only).
Every decision is logged as a JSON line without credential content.

## Verifier releases

The verifier routes are the same in the W-Stack releases 1.2.x and 1.3.x; only the body that
creates a presentation request differs. `loginProvider.verifier.api` selects it:

| `api` | Verifier | Create request body |
|---|---|---|
| `cvs-1.3` (default) | 1.3.x | `{permissionSet, ttl}`; the client id comes from the tenant's verifier profile |
| `cvs-1.2` | 1.2.x | `{presentationPolicyId, clientId, ttl}` |

## Deploy

1. **Policy bundle.** Write the deployment data (trusted issuers, the organisations each one may
   vouch for, the roles per application) as `facis/login_config/data.json` in a directory of your
   own (format in [the bundle README](../../infrastructure/opa/README.md#deployment-data)), then:
   ```bash
   opa build infrastructure/opa/bundle <deployment-data-dir> -o bundle.tar.gz
   kubectl -n <ns> create configmap facis-policy-bundle --from-file=bundle.tar.gz
   ```
2. **Secrets.** Either let the chart render them from values (`hydra.systemSecret`,
   `postgres.password`, `loginProvider.adminToken`), or create them and name them in
   `existingSecrets` (keys in `values.yaml`).
3. **Install.** Sync the flow into the chart, then install with your values:
   ```bash
   services/guard/helm/facis-guard/sync-flows.sh
   helm upgrade --install guard services/guard/helm/facis-guard -n <ns> -f <your-values.yaml>
   ```
   Required values: `publicUrl` (https), `clients`, `loginProvider.verifier.*`,
   `loginProvider.statusListOrigins`; `helm template` names any that is missing.
4. **Applications.** Each application is a public OAuth2 client (`clients`), uses code + PKCE
   against `publicUrl`, and checks tokens against `<publicUrl>/.well-known/jwks.json`. For AI
   Insight: `AI_INSIGHT_AUTH__ISSUER=<publicUrl>/`, `AI_INSIGHT_AUTH__JWKS_URL=<publicUrl>/.well-known/jwks.json`,
   `AI_INSIGHT_AUTH__ROLES_CLAIM=roles`, `AI_INSIGHT_AUTH__AUDIENCE` = the client's audience.

The ingress routes only `/oauth2/`, `/.well-known/`, `/userinfo` and the login pages. The
authorization server's admin API, the lockout endpoints and the policy engine stay inside the
cluster, and network policies restrict who reaches them.

Attempts and lockouts are held in the login provider's memory: one replica, and a restart ends
the logins in progress.

## Test

**Flow tests** (Node.js 20+, no install needed):
```bash
cd services/guard/orce/tests && npm test
```
They run the real function-node code of the flow JSON (with the DSP connector's
`run-node.js`), the HTTP replies being played by the tests.

**Policy tests:** `opa test infrastructure/opa/bundle` and `infrastructure/opa/check-fixtures.sh`.

**End to end on a local cluster** (kind, k3d, minikube; needs kubectl, helm, opa, openssl, curl,
jq). The local setup installs the chart in namespace `guard-local` with a stub verifier, which
plays the wallet's side and the issuer's status list, and an edge proxy on
`http://localhost:8444`:
```bash
services/guard/local/up.sh      # install (dev mode), port-forward localhost:8444
services/guard/local/e2e.sh     # the end-to-end check
services/guard/local/down.sh    # remove everything
```
`e2e.sh` runs real OAuth2 logins through Hydra and the login provider and checks: a valid
presentation gives a JWT that verifies against the JWKS, with the expected issuer, audience,
subject, claims and lifetime, and no refresh token; revoked credential, untrusted issuer, role not
allowed for the application, wrong nonce and another holder's credential are refused; five
refusals lock the address out and an administrator lifts it; the admin APIs are not routed.
`e2e.sh --token <role>` prints one access token, for testing an application locally.

The stub verifier signs and verifies nothing: the end-to-end check proves the guard's own logic
and wiring, not the W-Stack. Against a real verifier, set `loginProvider.verifier.*` and
`loginProvider.statusListOrigins` to it and present from a wallet.
