package facis.ai_insight

# fixture 50 — vocabulary: AI requires the ai_insight purpose (not "analytics")
test_fixture_ai_insight_allow if {
	allow.allow == true with input as {"roles": ["data_scientist"], "purpose": ["ai_insight"]}
}

# fixture 51 — analytics alone does not open AI Insight
test_fixture_ai_insight_deny_analytics_purpose if {
	allow.allow == false with input as {"roles": ["data_scientist"], "purpose": ["analytics"]}
}

# vocabulary: administrator is an AI role
test_ai_insight_allow_administrator if {
	allow.allow == true with input as {"roles": ["administrator"], "purpose": ["ai_insight", "operations"]}
}

# vocabulary: data_engineer is NOT an AI role
test_ai_insight_deny_data_engineer if {
	allow.allow == false with input as {"roles": ["data_engineer"], "purpose": ["ai_insight"]}
}

test_ai_insight_deny_no_purpose if {
	allow.allow == false with input as {"roles": ["data_scientist"], "purpose": []}
}
