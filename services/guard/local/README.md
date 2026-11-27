# Local setup: the guard and a wallet login on your machine

A linear path to run the guard (Ory Hydra, the ORCE login provider, the policy engine) on a
local Kubernetes cluster, check it end to end, and log in to the AI Insight UI through it.
Allow about 20 minutes the first time. Local tests only: dev mode, plain http, test credentials.

There are two levels:

| Level | What is real | What it proves | Needs |
|---|---|---|---|
| 1 (steps 1–6) | The guard. A stub plays the wallet, the credential verifier and the issuer's status list | The guard's logic and wiring, its tokens, the UI login | A laptop with Docker |
| 2 (step 7) | Also the OCM W-Stack (issuer, verifier, status lists) in a second cluster, and a test wallet with its own key | The whole chain with a real SD-JWT VC | A local W-Stack, about 10 GiB of RAM |

All paths below are from the repository root.

## 0. Prerequisites

| Tool | Tested with | For |
|---|---|---|
| Docker Engine | 20.10+ | kind |
| kind | 0.33 | the local cluster (k3d or minikube also work) |
| kubectl | 1.35 | |
| helm | 4.3 (3.x works too) | the guard's chart |
| opa | 1.22 | builds the policy bundle |
| openssl, curl, jq | any | secrets and checks |
| Node.js + npm | 20+ | the flow tests, the UI, the test wallet |

Free ports: 8444 (the guard) and 3000 (the UI's dev server).

## 1. Unit tests (optional, 1 minute)

```bash
(cd services/guard/orce/tests && npm test)       # the login provider's flow
opa test infrastructure/opa/bundle               # the login policy
```

## 2. A local cluster

```bash
kind create cluster --name facis                 # skip if you already have a local cluster
export KUBE_CONTEXT=kind-facis
```

`up.sh` refuses any context that isn't a local cluster (`kind-*`, `k3d-*`, `minikube`, ...).

## 3. Install the guard

```bash
services/guard/local/up.sh
```

It does the following:

- installs the chart in namespace `guard-local` (`NAMESPACE` to change it), with
  `values-local.yaml`, the stub verifier and an edge proxy;
- creates the secrets once, and keeps them across later runs;
- rolls the login provider when its flow changed, and restarts the policy engine so it loads
  the current bundle;
- leaves a port-forward running in the background: the guard is at **http://localhost:8444**.

You can re-run it safely. The first run pulls the images and takes a few minutes.

## 4. The end-to-end check

```bash
services/guard/local/e2e.sh
```

Expect `21 passed`. It runs real OAuth2 logins through Hydra and the login provider, and checks:

- the token: signature against the JWKS, issuer, audience, subject, claims, lifetime, no refresh
  token;
- the refusals: revoked credential, untrusted issuer, a role not allowed for the application,
  wrong nonce, another holder's credential;
- the lockout after five refusals, and an administrator lifting it;
- that the admin APIs aren't routed.

`e2e.sh --token <role>` prints one access token, for testing an API locally.

## 5. Log in from a browser

**Without an application.** Open this URL, which is a login for the UI's client, with a fixed
PKCE challenge:

```
http://localhost:8444/oauth2/auth?response_type=code&client_id=facis-ai-insight-ui&redirect_uri=http%3A%2F%2Flocalhost%3A8444%2Fcallback&scope=openid&state=abcdefgh&code_challenge=E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cQ&code_challenge_method=S256
```

1. The guard's login page appears, with the QR code, the wallet buttons and "Waiting for your
   wallet…".
2. In a terminal, play the wallet: `services/guard/local/present.sh data_analyst`.
3. Within about two seconds, the browser goes to `localhost:8444/callback?code=…`. That page is a
   404, because nothing listens there, but the `code` in its URL is the result.

**With the AI Insight UI** (its login goes through the guard, `VITE_OIDC_*`):

```bash
cd services/ai-insight-ui/ui/app
npm ci
printf 'VITE_OIDC_ISSUER=http://localhost:8444/\nVITE_OIDC_CLIENT_ID=facis-ai-insight-ui\nVITE_OIDC_AUDIENCE=facis-ai-insight\n' > .env.local
npm run dev                                      # leave it running
```

1. Open **http://localhost:3000/orce/aiInsight/**. Use `localhost`: it's the redirect address
   `values-local.yaml` registers.
2. You land on the guard's login page.
3. Run `services/guard/local/present.sh data_analyst`. The page returns to the UI, logged in.

Notes:

- `present.sh operator` is refused: the local policy doesn't allow that role for the UI.
- The pages stay empty without the simulation and its MQTT broker (`services/simulation`).
  Trino and the AI insights aren't available locally.
- Delete `.env.local` before building the UI bundle, or the local issuer gets built in.

## 6. Clean up

```bash
services/guard/local/down.sh                     # the port-forward and the namespace
kind delete cluster --name facis                 # if you created it for this
```

## 7. Level 2: a real W-Stack (optional)

The guard runs in its cluster, and the W-Stack in a second one: the trust services aren't part of
the FAP deployment. Install the W-Stack with the `eclipse-xfsc/deployment` charts in its own
kind cluster, with a tenant whose public host has a certificate from a CA you hold.

The scripts in `wstack/` prepare both sides. Each one takes its cluster, hosts and addresses as
settings, and its header lists them. Put yours in a file outside the repository and `source` it:

```bash
export KUBE_CONTEXT=kind-facis                   # the guard's cluster
export WSTACK_CONTEXT=kind-wstack                # the W-Stack's cluster
export WSTACK_NODE=wstack-control-plane WSTACK_NETWORK=kind-wstack WSTACK_NODE_IP=<its address>
export FAP_NODE=facis-control-plane FAP_NODE_IP=<the guard node's address on that network>
export WSTACK_HOST=<the tenant's public host>    # issuer, verifier, status lists
export TLS_SECRET=<namespace/name of the tenant's TLS secret>
export CA_FILE=<PEM of the CA of the W-Stack's certificates>
export NODE_EXTRA_CA_CERTS="${CA_FILE}"          # for test-wallet.js
export VERIFIER_URL=http://<W-Stack node address>:32093
export VCT=https://<tenant host>/api/schema/<SD-JWT credential type>
export VERIFIER_IMAGE=<credential-verification-service 1.3.17-alpha or later, by digest>
export SDJWT_IMAGE=<sd-jwt-service 1.2.14 or later, by digest>
export ORG_DID=did:web:<tenant host> E2E_ISSUER=did:web:<tenant host> E2E_ORG=did:web:<tenant host>
export WALLET_FILE="$HOME/.guard-local-test-wallet.json"
```

Then:

```bash
cd services/guard/local
wstack/connect-clusters.sh       # the guard's node joins the W-Stack's Docker network
wstack/wstack-local-fixes.sh     # verifier and SD-JWT service releases, CA trust
wstack/public-routes.sh          # nonce, credential and status list routes for the tenant
wstack/expose-verifier.sh        # the verifier's internal API, for the guard's node only
wstack/verifier-profile.sh       # the guard's permission set: one SD-JWT VC with org and roles
wstack/level2-config.sh ~/guard-level2
EXTRA_VALUES=~/guard-level2/values.yaml POLICY_DATA=~/guard-level2/policy-data ./up.sh
PRESENT_CMD=wstack/wallet-present.sh E2E_HOLDER="$(node test-wallet.js holder)" ./e2e.sh
```

Expect `14 passed, 3 skipped`. The skipped cases are those the wallet can't play: a revoked
credential, an untrusted issuer, and therefore the lockout. The guard README's "Against a real
W-Stack (level 2)" section explains what each fix is for.

**In the browser at level 2:**

1. Have the W-Stack issue a credential to the wallet: `wstack/issue.sh '["data_analyst"]'`.
2. Open the UI or the URL of step 5.
3. Right-click **"Open a wallet on this device"** and copy the link.
4. Run `node test-wallet.js present '<link>'`.

A phone can't scan the QR code here: the W-Stack has a private address and a local CA.

## After a reboot

The kind clusters restart with Docker, but the port-forward doesn't, and neither does anything
you kept under `/tmp`.

**Level 1:**

```bash
export KUBE_CONTEXT=kind-facis
kubectl --context "$KUBE_CONTEXT" -n guard-local get pods      # all Running after a minute or two
services/guard/local/up.sh                                     # restores the port-forward
```

Then `npm run dev` again for the UI.

**Level 2, the W-Stack first:**

- **OpenBao comes back sealed:** unseal it with your unseal keys. Until then, the services
  that read their credentials from it crash-loop.
- **The secret stores stay invalid:** External Secrets marked its secret stores invalid while
  OpenBao was sealed, and re-checks them only on its back-off. Make it re-check them now, then
  resync the external secrets:
  ```bash
  W="kubectl --context $WSTACK_CONTEXT"
  $W annotate clustersecretstores --all revalidate=$(date +%s) --overwrite
  $W annotate secretstores -A --all revalidate=$(date +%s) --overwrite
  $W get clustersecretstores,secretstores -A                     # all Ready
  for ns in $($W get externalsecrets -A --no-headers -o custom-columns=:.metadata.namespace | sort -u); do
    $W -n "$ns" annotate externalsecrets --all force-sync=$(date +%s) --overwrite
  done
  ```
- **Some deployments stay in crash-loop back-off:** restart those that crash-looped meanwhile
  (`kubectl rollout restart`).
- **The node addresses may have swapped:** check them with
  `docker network inspect $WSTACK_NETWORK`. The W-Stack's hosts are built on `WSTACK_NODE_IP`, so
  if the addresses changed, stop the guard's node, start the W-Stack's, then start the guard's
  again.

Then re-run `level2-config.sh` if its output was under `/tmp`, and re-run `up.sh` with
`EXTRA_VALUES` and `POLICY_DATA`.
