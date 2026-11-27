# participant.rego — package participant (participant lifecycle
# actions: issue/revoke are administrator-only, from the frozen vocabulary).
# Query: POST /v1/data/facis/participant/allow
#   {"input": {"action": "issue", "caller_roles": [...], "org_did": ...}}
# Decision object: {"allow": bool, "reason": str}. Deny by default.
# The deny branches are an else-chain: two deny rules producing different
# values on the same input would raise an OPA conflict (HTTP 500).
package facis.participant

default allow := {"allow": false, "reason": "deny by default"}

allow := {"allow": true, "reason": "administrator may run the participant admin action"} if {
	input.action in data.facis.vocabulary.participant.admin_actions
	"administrator" in data.facis.common.effective_roles(input.caller_roles)
	data.facis.common.valid_did(input.org_did)
} else := {"allow": false, "reason": "invalid or missing org_did"} if {
	not data.facis.common.valid_did(input.org_did)
} else := {"allow": false, "reason": sprintf("action %s requires the administrator role", [input.action])} if {
	input.action in data.facis.vocabulary.participant.admin_actions
} else := {"allow": false, "reason": sprintf("unknown participant action: %s", [input.action])}
