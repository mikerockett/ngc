module helpers

import regex

pub fn regex_valid(re_query string) bool {
	regex.regex_opt(re_query) or { return false }
	return true
}

pub fn regex_match(val string, re_query string) bool {
	if !regex_valid(re_query) {
		eprintln('Regex $re_query is invalid.')
		exit(1)
	}
	mut re := regex.regex_opt(re_query) or { return false }
	start, _ := re.match_string(val)
	return start != regex.no_match_found
}
