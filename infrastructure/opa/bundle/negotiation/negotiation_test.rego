package facis.negotiation

# fixture 30 — bundle API shape
test_fixture_negotiation_allow if {
	allow.allow == true with input as {
		"org_did": "did:web:org-x.facis.cloud", "roles": ["data_consumer"],
		"offer_purpose": "analytics", "offer_id": "offer-allowed-1", "dataset": "dataset-1",
	}
}

test_fixture_negotiation_deny_empty_did if {
	allow.allow == false with input as {
		"org_did": "", "roles": ["data_consumer"],
		"offer_purpose": "analytics", "offer_id": "offer-allowed-1", "dataset": "dataset-1",
	}
}

test_negotiation_deny_unknown_purpose if {
	allow.allow == false with input as {
		"org_did": "did:web:org-x.facis.cloud", "roles": ["data_consumer"],
		"offer_purpose": "world_domination", "offer_id": "offer-allowed-1", "dataset": "dataset-1",
	}
}

# fixture 33 — the DSP connector flow shape (permit)
test_fixture_permit_allow if {
	permit.allow == true with input as {
		"subject": {"did": "did:web:org-x.facis.cloud", "roles": ["data_consumer"]},
		"action": "negotiation.permit",
		"resource": {"negotiationId": "neg-1", "offerId": "offer-allowed-1", "dataset": "dataset-1"},
		"context": {"purpose": "analytics", "constraints": [{"type": "purpose", "value": "analytics"}]},
	}
}

# An absent purpose is DENIED
test_permit_deny_missing_purpose if {
	permit.allow == false with input as {
		"subject": {"did": "did:web:org-x.facis.cloud", "roles": ["data_consumer"]},
		"action": "negotiation.permit",
		"resource": {"negotiationId": "neg-2", "offerId": "offer-allowed-1", "dataset": "dataset-1"},
		"context": {"constraints": []},
	}
}

# Unknown dataset denied
test_permit_deny_unknown_dataset if {
	permit.allow == false with input as {
		"subject": {"did": "did:web:org-x.facis.cloud", "roles": ["data_consumer"]},
		"action": "negotiation.permit",
		"resource": {"negotiationId": "neg-3", "offerId": "offer-allowed-1", "dataset": "dataset-unknown"},
		"context": {"purpose": "analytics", "constraints": []},
	}
}

test_permit_deny_bad_constraint_type if {
	permit.allow == false with input as {
		"subject": {"did": "did:web:org-x.facis.cloud", "roles": ["data_consumer"]},
		"action": "negotiation.permit",
		"resource": {"negotiationId": "neg-4", "offerId": "offer-allowed-1", "dataset": "dataset-1"},
		"context": {"purpose": "analytics", "constraints": [{"type": "location", "value": "EU"}]},
	}
}

# did:"" must not leave the result undefined
test_permit_empty_did_is_deny_not_undefined if {
	permit.allow == false with input as {
		"subject": {"did": "", "roles": ["data_consumer"]},
		"action": "negotiation.permit",
		"resource": {"negotiationId": "neg-5", "offerId": "offer-allowed-1", "dataset": "dataset-1"},
		"context": {"purpose": "analytics", "constraints": []},
	}
}

# The negotiation subject is a DSP PARTICIPANT (credential participantRoles),
# not a user role: a user role alone must be DENIED.
test_permit_deny_user_role_not_participant if {
	permit.allow == false with input as {
		"subject": {"did": "did:web:org-x.facis.cloud", "roles": ["data_analyst"]},
		"action": "negotiation.permit",
		"resource": {"negotiationId": "neg-6", "offerId": "offer-allowed-1", "dataset": "dataset-1"},
		"context": {"purpose": "analytics", "constraints": []},
	}
}

test_permit_deny_no_roles if {
	permit.allow == false with input as {
		"subject": {"did": "did:web:org-x.facis.cloud", "roles": []},
		"action": "negotiation.permit",
		"resource": {"negotiationId": "neg-7", "offerId": "offer-allowed-1", "dataset": "dataset-1"},
		"context": {"purpose": "analytics", "constraints": []},
	}
}

test_permit_allow_provider_role if {
	permit.allow == true with input as {
		"subject": {"did": "did:web:org-x.facis.cloud", "roles": ["data_provider"]},
		"action": "negotiation.permit",
		"resource": {"negotiationId": "neg-8", "offerId": "offer-allowed-1", "dataset": "dataset-1"},
		"context": {"purpose": "analytics", "constraints": []},
	}
}

test_allow_deny_user_role_not_participant if {
	allow.allow == false with input as {
		"org_did": "did:web:org-x.facis.cloud", "roles": ["administrator"],
		"offer_purpose": "analytics", "offer_id": "offer-allowed-1", "dataset": "dataset-1",
	}
}
