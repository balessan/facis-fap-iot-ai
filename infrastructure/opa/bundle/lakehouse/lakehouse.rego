# lakehouse.rego — package lakehouse: read access to the Trino catalog
# fap-iotai-stackable, layers bronze/silver/gold, per the permissions in
# data.facis.vocabulary. Column restriction: bronze.consumer and
# silver.consumer_load carry consumer-level identifiers, visible only to administrator and data_engineer.
# Operator on gold is limited to the three operator tables.
# Query: POST /v1/data/facis/lakehouse/read
#   {"input": {"roles": [...], "layer": "gold", "table": "streetlight_zone_hourly",
#              "columns": ["zone_id", ...]}}
# Decision object: {"allow": bool, "reason": str}. Deny by default.
package facis.lakehouse

default read := {"allow": false, "reason": "deny by default"}

layer_known(layer) if {
	layer in object.keys(data.facis.vocabulary.catalogue.layers)
}

role_allowed_on(layer, roles) if {
	some r in data.facis.common.effective_roles(roles)
	r in data.facis.vocabulary.catalogue.layers[layer].allowed_roles
}

# operator on gold may only read the three operator tables; an operator
# accompanied by a stronger role is governed by that role (rules are
# mutually exclusive: at most one matches, otherwise the value is undefined
# and the caller treats it as deny)
table_allowed(_, _, roles) if {
	not "operator" in data.facis.common.effective_roles(roles)
}

table_allowed(_, _, roles) if {
	"operator" in data.facis.common.effective_roles(roles)
	not data.facis.common.effective_roles(roles) == ["operator"]
}

table_allowed(layer, table, roles) if {
	data.facis.common.effective_roles(roles) == ["operator"]
	layer == "gold"
	table in data.facis.vocabulary.catalogue.layers.gold.operator_tables
}

# restricted tables (consumer identifiers) need administrator or data_engineer
table_unrestricted(layer, table, roles) if {
	key := sprintf("%s.%s", [layer, table])
	not key in object.keys(data.facis.vocabulary.lakehouse.restricted_tables)
} else if {
	key := sprintf("%s.%s", [layer, table])
	some r in data.facis.common.effective_roles(roles)
	r in data.facis.vocabulary.lakehouse.restricted_tables[key].restricted_to
}

read := {"allow": true, "reason": sprintf("role may read %s.%s", [input.layer, input.table])} if {
	layer_known(input.layer)
	role_allowed_on(input.layer, input.roles)
	table_allowed(input.layer, input.table, input.roles)
	table_unrestricted(input.layer, input.table, input.roles)
} else := {"allow": false, "reason": sprintf("unknown layer: %s", [input.layer])} if {
	not layer_known(input.layer)
} else := {"allow": false, "reason": sprintf("no caller role may read layer %s", [input.layer])} if {
	layer_known(input.layer)
	not role_allowed_on(input.layer, input.roles)
} else := {"allow": false, "reason": sprintf("table %s.%s is not in the operator's gold subset", [input.layer, input.table])} if {
	layer_known(input.layer)
	role_allowed_on(input.layer, input.roles)
	not table_allowed(input.layer, input.table, input.roles)
} else := {"allow": false, "reason": sprintf("table %s.%s carries consumer identifiers — administrator/data_engineer only", [input.layer, input.table])}
