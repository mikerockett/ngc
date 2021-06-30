module helpers

import term
import os

fn valid_string_prompt(input string) (bool, string) {
  return true, ''
}

type StringValidationCallback = fn (input string) (bool, string)

pub struct StringPrompt {
  message string [required]
  default string
  required bool
  validator StringValidationCallback = valid_string_prompt
}

pub fn ask(prompt StringPrompt) string {
  default_str := if prompt.default == '' { 'required' } else { '$prompt.default' }
  input := os.input(term.yellow('? ') + prompt.message + term.dim(' [$default_str] '))

  if prompt.required && input == '' {
    eprintln(term.red('  input is required'))
    return ask(prompt)
  }

  mut output := if input.len > 0 { input } else { prompt.default }
  output = output.trim_space()

  valid, err := prompt.validator(output)

  if !valid {
    eprintln(term.red('  input is invalid: $err'))
    return ask(prompt)
  }

  return output
}
