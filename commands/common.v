module commands

import term
import os
import cli { Command }

pub fn welcome(command Command) {
	term.clear()
	title := 'nginx configurator: $command.description'
	println(term.bright_green('-'.repeat(title.len)))
	println(term.bright_green(title))
	println(term.bright_green('-'.repeat(title.len)))
	preflight()
}

pub fn preflight() {
	println(term.bright_blue('→ running preflight checks'))
	ensure_supported_user_os()
	ensure_running_as_root()
	ensure_dependencies_are_installed()
	ensure_dependencies_can_run()
	println(term.ok_message('✔ preflight checks complete'))
}

pub fn ensure_supported_user_os() {
	println(term.dim('- ensuring os supported'))
	os := os.user_os()
	if os.trim_space() !in ['linux', 'macos'] {
		eprintln(term.red('⨉ $os is not supported'))
		exit(1)
	}
	term.cursor_up(1)
	term.erase_line_clear()
	println(term.bright_green('- os supported'))
}

pub fn ensure_running_as_root() {
	println(term.dim('- ensuring running as root'))
	result := os.exec('id -u') or {
		eprintln(term.red('unable to get user id'))
		exit(1)
	}
	if result.output.trim_space() !in ['0', '501'] {
		eprintln(term.red('⨉ must be running as root, quitting'))
		exit(1)
	}
	term.cursor_up(1)
	term.erase_line_clear()
	println(term.bright_green('- running as root'))
}

pub fn ensure_dependencies_are_installed() {
	println(term.dim('- ensuring dependencies are installed'))
	for dependency in ['certbot', 'nginx', 'dig'] {
		if !os.exists_in_system_path(dependency) {
			eprintln(term.red('$dependency is not installed'))
			exit(1)
		}
	}
	term.cursor_up(1)
	term.erase_line_clear()
	println(term.bright_green('- dependencies are installed'))
}

pub fn ensure_dependencies_can_run() {
	println(term.dim('- ensuring dependencies can run'))
	for command in ['nginx -version', 'certbot --version', 'dig -v'] {
		os.exec(command) or {
			eprintln(term.red('unable to run dependency: $command'))
			exit(1)
		}
	}
	term.cursor_up(1)
	term.erase_line_clear()
	println(term.bright_green('- dependencies can run'))
}

pub fn yes_no(condition bool) string {
	return match condition {
		true { 'yes' }
		false { 'no' }
	}
}
