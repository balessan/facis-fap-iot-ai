package facis.transfer

# fixture 40
test_fixture_transfer_allow if {
	allow.allow == true with input as {"format": "http-pull", "roles": ["data_analyst"], "agreement_state": "FINALIZED", "purpose": ["analytics"]}
}

# fixture 41
test_fixture_transfer_deny_not_final if {
	allow.allow == false with input as {"format": "http-pull", "roles": [], "agreement_state": "REQUESTED", "purpose": ["analytics"]}
}

test_transfer_deny_unknown_format if {
	allow.allow == false with input as {"format": "ftp", "roles": ["data_analyst"], "agreement_state": "FINALIZED", "purpose": ["analytics"]}
}

test_transfer_deny_no_roles if {
	allow.allow == false with input as {"format": "http-pull", "roles": [], "agreement_state": "FINALIZED", "purpose": ["analytics"]}
}

# A declared purpose is required
test_transfer_deny_no_purpose if {
	allow.allow == false with input as {"format": "http-pull", "roles": ["data_analyst"], "agreement_state": "FINALIZED"}
}
