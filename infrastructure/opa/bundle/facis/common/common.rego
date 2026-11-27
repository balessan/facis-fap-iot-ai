# common.rego — shared helpers for the FACIS policy bundle.
# Design rules:
#   (i)  no business knowledge in the rego — roles/purposes/layers live in
#        data.facis.vocabulary, the code only encodes decision shapes;
#   (ii) claims are input only, never negotiated client-side;
#   (iii) rego traps: undefined != false — every check is an explicit
#        predicate, deny-by-default lives in each package's `default`;
#   (iv) any claim interpolated downstream passes a format check here.
package facis.common

# valid_did: format check on the org_did claim before any use (rule iv).
valid_did(did) if {
	is_string(did)
	regex.match(data.facis.vocabulary.did_pattern, did)
}

# effective_roles: the caller's roles INTERSECTED with the frozen vocabulary.
# Tokens from an identity provider can also carry its default roles (for
# example Keycloak's offline_access and default-roles-*). Those are filtered
# out here, not treated as unknown business roles, so they never deny a user.
effective_roles(roles) := [r | some r in roles; r in data.facis.vocabulary.roles]

# roles_known: at least one KNOWN role must be present. The signature check
# (the token issuer's JWKS, or the W-Stack verifier for presentations) is what
# makes the claims trustworthy; this filter only drops provider-default noise.
roles_known(roles) if {
	is_array(roles)
	count(effective_roles(roles)) > 0
}

# purposes_known: every declared purpose must be in the frozen vocabulary.
purposes_known(purposes) if {
	is_array(purposes)
	count(purposes) > 0
	every p in purposes { p in data.facis.vocabulary.purposes }
}
