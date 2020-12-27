module ngc_helpers

import term
import os { input }

pub struct ConfirmationPrompt {
	message string [required]
	default bool
}

pub fn confirm(prompt ConfirmationPrompt) bool {
	default_str := if prompt.default { 'yes' } else { 'no' }
	input := input(term.bright_green('? ') + prompt.message + term.dim(' [y/n] ') + term.dim('$default_str '))
	return match input {
		'yes', 'Y', 'y' { true }
		'no', 'N', 'n' { false }
		else { input.bool() }
	}
}
