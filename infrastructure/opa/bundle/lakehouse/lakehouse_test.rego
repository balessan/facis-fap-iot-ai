package facis.lakehouse

# vocabulary: bronze = administrator + data_engineer
test_bronze_engineer_allow if {
	read.allow == true with input as {"roles": ["data_engineer"], "layer": "bronze", "table": "consumer", "columns": ["ts"]}
}

test_bronze_analyst_deny if {
	read.allow == false with input as {"roles": ["data_analyst"], "layer": "bronze", "table": "events", "columns": ["ts"]}
}

# vocabulary: silver = administrator, data_engineer, data_scientist
test_silver_scientist_allow if {
	read.allow == true with input as {"roles": ["data_scientist"], "layer": "silver", "table": "net_grid_hourly", "columns": ["ts"]}
}

test_silver_operator_deny if {
	read.allow == false with input as {"roles": ["operator"], "layer": "silver", "table": "net_grid_hourly", "columns": ["ts"]}
}

# vocabulary: gold = administrator, data_engineer, data_scientist, data_analyst + operator (3 tables)
test_gold_operator_table_allow if {
	read.allow == true with input as {"roles": ["operator"], "layer": "gold", "table": "streetlight_zone_hourly", "columns": ["zone_id"]}
}

test_gold_operator_other_table_deny if {
	read.allow == false with input as {"roles": ["operator"], "layer": "gold", "table": "consumer_insights", "columns": ["c"]}
}

test_gold_engineer_allow if {
	read.allow == true with input as {"roles": ["data_engineer"], "layer": "gold", "table": "anomaly_candidates", "columns": ["c"]}
}

# column restriction: bronze.consumer / silver.consumer_load = admin+engineer only
test_consumer_load_scientist_deny if {
	read.allow == false with input as {"roles": ["data_scientist"], "layer": "silver", "table": "consumer_load", "columns": ["load_kw"]}
}

test_consumer_load_admin_allow if {
	read.allow == true with input as {"roles": ["administrator"], "layer": "silver", "table": "consumer_load", "columns": ["load_kw", "consumer_id"]}
}

test_unknown_layer_deny if {
	read.allow == false with input as {"roles": ["administrator"], "layer": "platinum", "table": "t", "columns": []}
}
