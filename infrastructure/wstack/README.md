# OCM W-Stack baseline

The identity integration of the FAP uses the OCM W-Stack services of the
federation. This directory pins the version of each of them, so that every
installation and test run targets the same release.

- `wstack-images.lock.tsv` lists every Helm chart and container image of the
  `ocm-wstack` ApplicationSet of
  [eclipse-xfsc/deployment](https://github.com/eclipse-xfsc/deployment), with
  its sha256 digest. The first line records the `deployment` commit it was
  built from.
- `mirror-wstack-images.sh` regenerates the lock from a `deployment` commit,
  and can copy the pinned images and charts to another registry.
  `list-images.py` is its helper that lists the images of rendered charts.
- `check-baseline.py` checks the lock, the registry and a running namespace.
  The tests of both are in `tests/`.

Tags on the XFSC registry can move and the charts pull with
`pullPolicy: Always`, so the digest is what counts, not the tag.

**The lock records and detects; it does not pin an installation.** The
`ocm-wstack` ApplicationSet installs from the `deployment` repository at its
own revision (`tag: main` in its values), so an Argo CD install follows that
branch, not this file. Use the lock to check what runs (`--cluster`), to
notice when the published tags move (`--registry`), and as the list to mirror.

## Required components

| Image | Constraint |
|---|---|
| `ocm-wstack/issuance-service` | |
| `ocm-wstack/pre-authorization-bridge` | |
| `ocm-wstack/credential-retrieval-service` | |
| `ocm-wstack/storage-service` | |
| `ocm-wstack/credential-verification-service` | 1.3.0 or later: the release line the FAP's presentation flows were tested with (DCQL queries from the tenant's presentation profiles, `/wallet/authorize`). A pre-release such as `1.3.0-alpha` is below `1.3.0` |
| `ocm-wstack/status-list-service` | |
| `ocm-wstack/well-known-service` | |
| `tsa/signer` | |
| `tsa/crypto-provider-hashicorp-vault-plugin` | |

Also in the lock but not required: `common-services/sd-jwt-service` (SD-JWT
credentials, not used by the FAP today), `tsa/policy`, the dummy content signer
and the offering bootstrap.

Not covered by the lock:

- Keycloak and PCM Cloud, which are not part of the `ocm-wstack` ApplicationSet.
- What other ApplicationSets install: the XFSC Kubernetes operator (the pods
  carry `inject.xfsc.io/enabled`), NATS, OpenBao and the External Secrets
  Operator, and the databases (Cassandra, Postgres).
- The DIDComm connector, which the ApplicationSet excludes. The Easy Stack
  Builder OCM-WStack node deploys it, on a `latest` tag.

## Checks

```bash
python3 infrastructure/wstack/check-baseline.py                              # lock file only
python3 infrastructure/wstack/check-baseline.py --expect-deployment 55e28aa  # and its deployment commit
python3 infrastructure/wstack/check-baseline.py --registry [--strict]        # tags moved since the lock (skopeo)
python3 infrastructure/wstack/check-baseline.py --cluster <namespace>        # pods run the pinned digests (kubectl)
python3 -m unittest discover -s infrastructure/wstack/tests
```

A moved tag is a warning unless `--strict` is given; the weekly CI run uses
`--strict`, so drift fails the run and notifies. `--strict` only applies with
`--registry`, and `--context` only with `--cluster`.

In `--cluster` mode, images are matched on their repository path, also when a
mirror adds a prefix (`<registry>/<prefix>/ocm-wstack/...`), so pods pulling
from a mirror are checked too. The check fails when a pod runs another digest,
and when a required image has no running container in the namespace. Images
that are not in the lock (NATS, Cassandra...) are only listed.

## Updating

```bash
infrastructure/wstack/mirror-wstack-images.sh --ref <deployment commit>
python3 infrastructure/wstack/check-baseline.py --expect-deployment <deployment commit>
```

Without `--apply` the script only writes the lock. Review its diff like a
dependency upgrade. If a chart fails to build or render, it stops without
writing the lock. With `--apply --target <registry>/<prefix>` it also copies
the images and charts by their locked digest and checks the digest at the
destination. Cosign signatures are not copied.

The script needs bash, git, helm 3.8 or later, skopeo and python3 with PyYAML
(`pip install -r infrastructure/wstack/requirements.txt`), and runs on Linux
and macOS. The checks only need python3 (plus skopeo or kubectl for the online
modes); the unit tests also need PyYAML.
