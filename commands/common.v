module commands

import term
import os
import lol as Lol
import cli { Command }

pub fn welcome(command Command) {
	lol := Lol.Lol{Lol.Config{Lol.Style.normal}}
	title := 'nginx configurator: $command.description'
	lol.print('-'.repeat(title.len))
	lol.print(title)
	lol.print('-'.repeat(title.len))
	preflight()
}

pub fn preflight() {
	println(term.bright_blue('→ running preflight checks'))
	ensure_dependencies_are_installed()
	ensure_dependencies_can_run()
	println(term.ok_message('✔ preflight checks complete'))
}

pub fn ensure_dependencies_are_installed() {
	println(term.dim('⊙ ensuring dependencies are installed'))
	for dependency in ['certbot', 'nginx', 'dig'] {
		if !os.exists_in_system_path(dependency) {
			eprintln(term.red('$dependency is not installed'))
		}
	}
	term.cursor_up(1)
	term.erase_line_clear()
	println(term.bright_green('⊙ dependencies are installed'))
}

pub fn ensure_dependencies_can_run() {
	println(term.dim('⊙ ensuring dependencies can run'))
	for command in ['nginx -version', 'certbot --version', 'dig -v'] {
		result := os.exec(command) or {
			eprintln('Unable to run dependency: $command')
			return
		}
		assert result.exit_code == 0
	}
	term.cursor_up(1)
	term.erase_line_clear()
	println(term.bright_green('⊙ dependencies can run'))
}

pub fn yes_no(condition bool) string {
	return match condition {
		true { 'yes' }
		false { 'no' }
	}
}
