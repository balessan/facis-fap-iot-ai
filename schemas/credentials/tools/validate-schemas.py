#!/usr/bin/env python3
"""Validate the credential examples against their JSON Schemas.

Every examples/<kind>.valid*.json must validate and every examples/<kind>.invalid-*.json
must fail, where <kind> is participant, role or service. Exit code 1 otherwise.

Usage: python3 schemas/credentials/tools/validate-schemas.py
Needs: jsonschema 4.18 or later (pip install -r schemas/credentials/tools/requirements.txt)
"""
import json
import sys
from pathlib import Path

from jsonschema import Draft202012Validator, FormatChecker
from referencing import Registry, Resource

SCHEMAS = Path(__file__).resolve().parent.parent
KINDS = {
    "participant": "FacisParticipantCredential.schema.json",
    "role": "FapIotAiRoleCredential.schema.json",
    "service": "FapServiceCredential.schema.json",
}


def load(path):
    return json.loads(path.read_text())


def main():
    resources = []
    for path in SCHEMAS.glob("*.schema.json"):
        schema = load(path)
        Draft202012Validator.check_schema(schema)
        resources.append((schema["$id"], Resource.from_contents(schema)))
    registry = Registry().with_resources(resources)

    failures = 0
    for example in sorted((SCHEMAS / "examples").glob("*.json")):
        kind = example.name.split(".")[0]
        validator = Draft202012Validator(
            load(SCHEMAS / KINDS[kind]), registry=registry, format_checker=FormatChecker()
        )
        errors = list(validator.iter_errors(load(example)))
        expect_valid = ".valid" in example.name
        ok = (not errors) if expect_valid else bool(errors)
        failures += not ok
        verdict = "valid" if not errors else f"invalid ({errors[0].message[:90]})"
        print(f"{'ok  ' if ok else 'FAIL'} {example.name}: {verdict}")
    print(f"{failures} unexpected result(s)")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
