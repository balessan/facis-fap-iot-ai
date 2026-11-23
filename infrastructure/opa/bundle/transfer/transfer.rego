# transfer.rego — package transfer: a data transfer may start only on a FINALIZED agreement, with a
# known transfer format, at least one known role and a declared known purpose.
# Query: POST /v1/data/facis/transfer/allow
#   {"input": {"format": "http-pull", "roles": [...], "agreement_state": "FINALIZED", "purpose": [...]}}
# Decision object: {"allow": bool, "reason": str}. Deny by default.
package facis.transfer

default allow := {"allow": false, "reason": "deny by default"}

allow := {"allow": true, "reason": "agreement FINALIZED, format, roles and purpose known"} if {
	input.agreement_state in data.facis.vocabulary.transfer.final_agreement_states
	input.format in data.facis.vocabulary.transfer.formats
	data.facis.common.roles_known(input.roles)
	data.facis.common.purposes_known(input.purpose)
} else := {"allow": false, "reason": sprintf("agreement not final: %s", [input.agreement_state])} if {
	not input.agreement_state in data.facis.vocabulary.transfer.final_agreement_states
} else := {"allow": false, "reason": sprintf("unknown transfer format: %s", [input.format])} if {
	input.agreement_state in data.facis.vocabulary.transfer.final_agreement_states
	not input.format in data.facis.vocabulary.transfer.formats
} else := {"allow": false, "reason": "no known role in the token claims"} if {
	input.agreement_state in data.facis.vocabulary.transfer.final_agreement_states
	input.format in data.facis.vocabulary.transfer.formats
	not data.facis.common.roles_known(input.roles)
} else := {"allow": false, "reason": "no purpose declared or purpose not in the vocabulary"}
