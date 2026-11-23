package facis.catalogue

# fixture 20-catalogue-allow (vocabulary: data_analyst reads gold)
test_fixture_catalogue_allow if {
	allow.allow == true with input as {"roles": ["data_analyst"], "layer": "gold", "purpose": ["analytics"]}
}

# fixture 21: operator on BRONZE is denied (vocabulary: bronze = admin+engineer only)
test_fixture_catalogue_deny_operator_on_bronze if {
	allow.allow == false with input as {"roles": ["operator"], "layer": "bronze", "purpose": ["operations"]}
}

# vocabulary: operator may see gold (table restriction is lakehouse.read's job)
test_catalogue_allow_operator_gold if {
	allow.allow == true with input as {"roles": ["operator"], "layer": "gold", "purpose": ["operations"]}
}

# data_engineer reads bronze, as the vocabulary says
test_catalogue_allow_engineer_bronze if {
	allow.allow == true with input as {"roles": ["data_engineer"], "layer": "bronze", "purpose": ["operations"]}
}

# data_analyst may NOT see bronze/silver
test_catalogue_deny_analyst_silver if {
	allow.allow == false with input as {"roles": ["data_analyst"], "layer": "silver", "purpose": ["analytics"]}
}

# A declared known purpose is required
test_catalogue_deny_no_purpose if {
	allow.allow == false with input as {"roles": ["data_analyst"], "layer": "gold"}
}

test_catalogue_deny_unknown_layer if {
	allow.allow == false with input as {"roles": ["data_analyst"], "layer": "platinum", "purpose": ["analytics"]}
}
