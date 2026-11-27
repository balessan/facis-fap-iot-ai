# login.rego — package login: the decision the guard's login provider asks
# for after a verified presentation, before it accepts the login.
# Query: POST /v1/data/facis/login/allow  {"input": {"org_did": ..., "roles": [...]}}
# Decision object: {"allow": bool, "reason": str}. Callers read .result.allow.
# Deny by default.
package facis.login

default allow := {"allow": false, "reason": "deny by default"}

allow := {"allow": true, "reason": "org_did valid and at least one known role"} if {
	data.facis.common.valid_did(input.org_did)
	data.facis.common.roles_known(input.roles)
} else := {"allow": false, "reason": "invalid or missing org_did"} if {
	not data.facis.common.valid_did(input.org_did)
} else := {"allow": false, "reason": "no known role in the claims (provider defaults filtered)"}
