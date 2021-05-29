module helpers

const (
  email_re = r'^(?:[-a-zA-Z0-9!#$%&.\'*+/=?^_`{|}~]+)|("(?:[-a-zA-Z0-9!#$%&.\'*+/=?^_`{|}~]+)")$'
)

pub fn validate_email(address string) bool {
  parts := address.split('@')

	if parts.len != 2 {
		return false
	}

	if !regex_match(parts[0], email_re) {
		return false
	}

	if !validate_fqdn(parts[1]) {
		return false
	}

	return true
}
