package facis.login

# fixture 60
test_fixture_login_allow if {
	allow.allow == true with input as {"roles": ["data_analyst"], "org_did": "did:web:org-x.facis.cloud"}
}

# fixture 61
test_fixture_login_deny_no_roles if {
	allow.allow == false with input as {"roles": [], "org_did": "did:web:org-x.facis.cloud"}
}

# Provider-default roles are filtered: a token that also carries them passes
test_login_allow_with_provider_defaults if {
	allow.allow == true with input as {"roles": ["offline_access", "default-roles-facis", "operator"], "org_did": "did:web:org-x.facis.cloud"}
}
