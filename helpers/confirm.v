module helpers

import term
import os

pub struct ConfirmationPrompt {
	message string [required]
	default bool
}

pub fn confirm(prompt ConfirmationPrompt) bool {
	default_str := if prompt.default { 'yes' } else { 'no' }
	input := os.input(term.yellow('? ') + prompt.message + term.dim(' [y/n] ') + term.dim('$default_str '))
	return input.trim_space().to_lower().contains_any_substr(['y', 'yes', 'true'])
}
