#!/usr/bin/env bash
# Replays the decision fixtures against the policy bundle with `opa eval`,
# without a server. Each fixture names a query (data path), an input and the
# expected verdict ("allow" or "deny"). Exits non-zero if any fixture gets
# another verdict.
#
# Usage: infrastructure/opa/check-fixtures.sh            (from the repo root)
# Needs: opa, jq.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
bundle="${here}/bundle"
failed=0
total=0

for fixture in "${here}"/fixtures/*.json; do
    name="$(basename "${fixture}" .json)"
    query="$(jq -r '.query' "${fixture}")"
    expect="$(jq -r '.expect' "${fixture}")"
    total=$((total + 1))

    result="$(jq '.input' "${fixture}" \
        | opa eval --bundle "${bundle}" --stdin-input --format raw \
            "data.${query//\//.}.allow")"
    if [ "${result}" = "true" ]; then got=allow; else got=deny; fi

    if [ "${got}" = "${expect}" ]; then
        echo "ok    ${name}: ${got}"
    else
        echo "FAIL  ${name}: expected ${expect}, got ${got}"
        failed=$((failed + 1))
    fi
done

echo "${total} fixtures, ${failed} failed"
[ "${failed}" -eq 0 ]
