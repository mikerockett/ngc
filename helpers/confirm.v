module helpers

import term
import os

pub struct ConfirmationPrompt {
	message string [required]
	default bool
}

pub fn confirm(prompt ConfirmationPrompt) bool {
	default_str := if prompt.default { 'yes' } else { 'no' }
	input := os.input(term.yellow('? ') + prompt.message + term.bright_green(' [y/n] ') + term.dim('$default_str ')).trim_space().to_lower()
	if input.len == 0 {
		return prompt.default
	}
	if input !in ['y', 'yes', 'n', 'no'] {
		eprintln(term.red('  Please use y[es] or n[o]'))
		confirm(prompt)
	}
	return input in ['y', 'Y']
}
