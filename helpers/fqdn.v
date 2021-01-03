module helpers

const (
	fqdn_max_label_length = 63
	fqdn_re_base          = r'^[-a-zA-Z0-9]+$'
	fqdn_re_tld           = r'^(([a-zA-Z]{2,})|(xn[-a-zA-Z0-9]{2,}))$'
)

pub fn validate_fqdn(hostname string) bool {
	parts := hostname.split('.')
	for part in parts {
		if part.len > fqdn_max_label_length {
			return false
		}
	}
	if parts.len < 2 {
		return false
	}
	tld := parts.last()
	if !regex_match(tld, fqdn_re_tld) {
		return false
	}
	for part in parts {
		if !regex_match(part, fqdn_re_base) {
			return false
		}
		if part[0] == `-` || part[part.len - 1] == `-` {
			return false
		}
	}
	return true
}
