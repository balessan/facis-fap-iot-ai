# catalogue.rego — package catalogue (dataset visibility by
# layer: which roles may see which catalogue layer lives in the vocabulary,
# not in this file).
# Query: POST /v1/data/facis/catalogue/allow
#   {"input": {"roles": [...], "layer": "gold", "purpose": [...]}}
# Decision object: {"allow": bool, "reason": str}. Deny by default.
# Any declared known purpose is required for non-AI access.
package facis.catalogue

default allow := {"allow": false, "reason": "deny by default"}

layer_allowed(layer, roles) if {
	some r in data.facis.common.effective_roles(roles)
	r in data.facis.vocabulary.catalogue.layers[layer].allowed_roles
}

allow := {"allow": true, "reason": sprintf("role may see layer %s with a declared purpose", [input.layer])} if {
	input.layer in object.keys(data.facis.vocabulary.catalogue.layers)
	layer_allowed(input.layer, input.roles)
	data.facis.common.purposes_known(input.purpose)
} else := {"allow": false, "reason": sprintf("unknown catalogue layer: %s", [input.layer])} if {
	not input.layer in object.keys(data.facis.vocabulary.catalogue.layers)
} else := {"allow": false, "reason": "no purpose declared or purpose not in the vocabulary"} if {
	input.layer in object.keys(data.facis.vocabulary.catalogue.layers)
	layer_allowed(input.layer, input.roles)
	not data.facis.common.purposes_known(input.purpose)
} else := {"allow": false, "reason": sprintf("no caller role is allowed on layer %s", [input.layer])}
