# ai_insight.rego — package ai_insight: AI Insight is open to administrator,
# data_scientist and data_analyst (the role list is in the vocabulary) and
# REQUIRES the `ai_insight` purpose in the token.
# Query: POST /v1/data/facis/ai_insight/allow  {"input": {"roles": [...], "purpose": [...]}}
# Decision object: {"allow": bool, "reason": str}. Deny by default.
package facis.ai_insight

default allow := {"allow": false, "reason": "deny by default"}

ai_role_present(roles) if {
	some r in data.facis.common.effective_roles(roles)
	r in data.facis.vocabulary.ai_insight.allowed_roles
}

purpose_ok(purposes) if {
	is_array(purposes)
	count(purposes) > 0
	every p in purposes { p in data.facis.vocabulary.purposes }
	data.facis.vocabulary.ai_insight.required_purpose in purposes
}

allow := {"allow": true, "reason": "AI-authorised role declaring the ai_insight purpose"} if {
	ai_role_present(input.roles)
	purpose_ok(input.purpose)
} else := {"allow": false, "reason": "no AI-authorised role in the token claims"} if {
	not ai_role_present(input.roles)
} else := {"allow": false, "reason": "the ai_insight purpose must be declared (and all purposes known)"}
