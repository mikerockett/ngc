module commands

import cli { Command }
import term
import os

pub fn welcome(command Command)! {
  term.clear()

  title := 'nginx configurator for php apps: $command.description'

  println(term.bright_green('-'.repeat(title.len)))
  println(term.bright_green(title))
  println(term.bright_green('-'.repeat(title.len)))

  preflight()
}

pub fn preflight() {
  println(term.bright_blue('running preflight checks'))

  ensure_supported_user_os()
  ensure_running_as_root()
  ensure_dependencies_are_installed()
  ensure_dependencies_can_run()

  println(term.bright_green('preflight checks complete'))
}

pub fn ensure_supported_user_os() {
  print(term.dim('ensuring os supported '))

  os := os.user_os()
  supported := $if prod { ['linux'] } $else { ['linux', 'macos'] }

  if os.trim_space() !in supported {
    eprintln(term.red('$os is not supported'))
    exit(1)
  }

  println(term.bright_green('ok'))
}

pub fn ensure_running_as_root() {
  print(term.dim('ensuring running as root '))

  result := os.execute('id -u')

  if result.exit_code != 0 {
    eprintln(term.red('unable to get user id'))
    exit(1)
  }

  supported := $if prod { ['0'] } $else { ['0', '501'] }

  if result.output.trim_space() !in supported {
    eprintln(term.red('⨉ must be running as root, quitting'))
    exit(1)
  }

  println(term.bright_green('ok'))
}

pub fn ensure_dependencies_are_installed() {
  print(term.dim('ensuring dependencies are installed '))

  for dependency in ['certbot', 'nginx', 'dig'] {
    if !os.exists_in_system_path(dependency) {
      eprintln(term.red('$dependency is not installed'))
      exit(1)
    }
  }

  println(term.bright_green('ok'))
}

pub fn ensure_dependencies_can_run() {
  print(term.dim('ensuring dependencies can run '))

  for command in ['nginx -v', 'certbot --version', 'dig -v'] {
    result := os.execute(command)
    if result.exit_code != 0 {
      eprintln(term.red('unable to run dependency: $command'))
      exit(1)
    }
  }

  println(term.bright_green('ok'))
}

pub fn yes_no(condition bool) string {
  return match condition {
    true { 'yes' }
    false { 'no' }
  }
}
