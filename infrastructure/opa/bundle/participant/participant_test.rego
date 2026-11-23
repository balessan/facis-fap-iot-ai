package facis.participant

# fixture 10
test_fixture_participant_allow if {
	allow.allow == true with input as {"action": "issue", "caller_roles": ["administrator"], "org_did": "did:web:org-x.facis.cloud"}
}

# fixture 11
test_fixture_participant_deny_non_admin if {
	allow.allow == false with input as {"action": "issue", "caller_roles": ["data_analyst"], "org_did": "did:web:org-x.facis.cloud"}
}

test_participant_revoke_requires_admin if {
	allow.allow == false with input as {"action": "revoke", "caller_roles": ["operator"], "org_did": "did:web:org-x.facis.cloud"}
}

# Non-admin + invalid DID must be a clean deny, NOT an OPA conflict (500)
test_participant_deny_invalid_did if {
	allow.allow == false with input as {"action": "issue", "caller_roles": ["administrator"], "org_did": ""}
}

test_participant_deny_non_admin_invalid_did_no_conflict if {
	allow.allow == false with input as {"action": "issue", "caller_roles": ["data_analyst"], "org_did": ""}
}
