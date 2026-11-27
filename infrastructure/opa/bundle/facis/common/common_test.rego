package facis.common

test_valid_did_accepts_did_web if valid_did("did:web:org-x.facis.cloud")
test_valid_did_accepts_did_key if valid_did("did:key:z6MkrJVnaZkeFTHpom2nn1fjgzir1vE7mhKRh")
test_valid_did_rejects_empty if not valid_did("")
test_valid_did_rejects_non_did if not valid_did("not-a-did")

test_roles_known_rejects_empty if not roles_known([])
test_roles_known_rejects_unknown_role if not roles_known(["superuser"])

# Provider-default roles are filtered, not fatal: a token with provider
# defaults (offline_access + default-roles-* + one business role) is accepted
test_roles_known_filters_provider_defaults if {
	roles_known(["offline_access", "default-roles-facis", "data_analyst"])
	effective_roles(["offline_access", "default-roles-facis", "data_analyst"]) == ["data_analyst"]
}
