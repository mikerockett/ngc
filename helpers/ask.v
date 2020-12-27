module helpers

import term
import os { input }

fn valid_string_prompt(input string) bool {
	return true
}

type StringValidationCallback = fn (input string) bool

pub struct StringPrompt {
	message   string                   [required]
	default   string
	required  bool
	validator StringValidationCallback = valid_string_prompt
}

pub fn ask(prompt StringPrompt) string {
	default_str := if prompt.default == '' { 'required' } else { prompt.default }
	input := input(term.bright_green('? ') + prompt.message + term.dim(' $default_str '))
	if prompt.required && input == '' {
		eprintln(term.red('  Input is required'))
		return ask(prompt)
	}
	if prompt.validator(input) == false {
		eprintln(term.red('  Input is invalid'))
		return ask(prompt)
	}
	return if input.len > 0 {
		input
	} else {
		prompt.default
	}
}
