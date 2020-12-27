module commands

import term
import os { exec, exists_in_system_path }
import cli { Command }

pub fn welcome(command Command) {
	println(term.green(term.bold('Nginx Configurator: ' + command.name)))
	preflight()
}

pub fn preflight() {
	println(term.bright_blue('▷ Running preflight checks…'))
	assert exists_in_system_path('nginx')
	assert exists_in_system_path('certbot')
	nginx_test := exec('nginx -version') or { panic('WHOOPS') }
	certbot_test := exec('certbot --version') or { panic('WHOOPS') }
	assert nginx_test.exit_code == 0
	assert certbot_test.exit_code == 0
	println(term.bright_green('✔ Preflight checks complete.'))
}
