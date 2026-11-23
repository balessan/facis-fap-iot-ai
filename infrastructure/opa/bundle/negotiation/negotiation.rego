# negotiation.rego — package negotiation: the single source for the
# negotiation.permit gate that the DSP connector's negotiation flow
# (facis-dsp-negotiations.json) asks before agreeing.
#
# Two query shapes, one decision logic:
#   POST /v1/data/facis/negotiation/permit   (DSP connector flow shape)
#     input := { subject: {did, roles}, action: "negotiation.permit",
#                resource: {negotiationId, offerId, dataset},
#                context: {purpose, constraints} }
#   POST /v1/data/facis/negotiation/allow    (bundle fixture API)
#     input := { org_did, roles, offer_purpose, offer_id, dataset }
# Decision: { allow: bool, reason: str }. Deny by default. Purpose is REQUIRED;
# offer AND dataset are checked.
#
# The subject of a negotiation is the DSP PARTICIPANT from the verified
# participant credential (participantRoles: data_provider / data_consumer),
# NOT a user role. known_roles therefore reads data.facis.vocabulary.participant_roles;
# data.facis.vocabulary.roles (administrator, data_engineer, …) stays reserved
# for the user-facing packages via facis.common.effective_roles.
package facis.negotiation

default permit := {"allow": false, "reason": "deny by default"}

default allow := {"allow": false, "reason": "deny by default"}

known_roles(roles) := [r | some r in roles; r in data.facis.vocabulary.participant_roles]

subject_ok(did, roles) if {
	data.facis.common.valid_did(did)
	count(known_roles(roles)) > 0
}

purpose_ok(purpose) if {
	is_string(purpose)
	purpose != ""
	purpose in data.facis.vocabulary.purposes
}

constraints_ok(constraints) if {
	every c in constraints { c.type in data.facis.vocabulary.negotiation.allowed_constraint_types }
}

offer_ok(offer_id, dataset) if {
	offer_id in data.facis.vocabulary.catalogue.allowed_offers
	dataset in data.facis.vocabulary.catalogue.allowed_datasets
}

# --- permit: the DSP connector flow gate ------------------------------------
permit := {"allow": true, "reason": "subject known, purpose declared and allowed, offer+dataset visible, constraints ok"} if {
	input.action == "negotiation.permit"
	subject_ok(input.subject.did, input.subject.roles)
	purpose_ok(input.context.purpose)
	offer_ok(input.resource.offerId, input.resource.dataset)
	constraints_ok(input.context.constraints)
} else := {"allow": false, "reason": "unauthenticated subject or no known role"} if {
	input.action == "negotiation.permit"
	not subject_ok(input.subject.did, input.subject.roles)
} else := {"allow": false, "reason": "purpose missing or not in the frozen vocabulary"} if {
	input.action == "negotiation.permit"
	subject_ok(input.subject.did, input.subject.roles)
	not purpose_ok(input.context.purpose)
} else := {"allow": false, "reason": sprintf("offer not visible or dataset unknown: %s / %s", [input.resource.offerId, input.resource.dataset])} if {
	input.action == "negotiation.permit"
	subject_ok(input.subject.did, input.subject.roles)
	purpose_ok(input.context.purpose)
	not offer_ok(input.resource.offerId, input.resource.dataset)
} else := {"allow": false, "reason": "constraint type not allowed"} if {
	input.action == "negotiation.permit"
	subject_ok(input.subject.did, input.subject.roles)
	purpose_ok(input.context.purpose)
	offer_ok(input.resource.offerId, input.resource.dataset)
	not constraints_ok(input.context.constraints)
} else := {"allow": false, "reason": "unknown action"}

# --- allow: the bundle fixture API, same logic on its input shape -------------
allow := {"allow": true, "reason": "org_did valid, roles known, offer purpose allowed, offer+dataset visible"} if {
	subject_ok(input.org_did, input.roles)
	purpose_ok(input.offer_purpose)
	offer_ok(input.offer_id, input.dataset)
} else := {"allow": false, "reason": "invalid or missing org_did / no known role"} if {
	not subject_ok(input.org_did, input.roles)
} else := {"allow": false, "reason": sprintf("offer purpose not allowed: %s", [input.offer_purpose])} if {
	subject_ok(input.org_did, input.roles)
	not purpose_ok(input.offer_purpose)
} else := {"allow": false, "reason": sprintf("offer not visible or dataset unknown: %s / %s", [input.offer_id, input.dataset])} if {
	subject_ok(input.org_did, input.roles)
	purpose_ok(input.offer_purpose)
	not offer_ok(input.offer_id, input.dataset)
} else := {"allow": false, "reason": "deny by default"}
