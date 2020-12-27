import term
import cli { Command, Flag }
import os { exists_in_system_path, exec }
import endeveit.validate.validators { is_fqdn }
import ngc_helpers { confirm, ask }

fn main() {
	term.clear()
	mut app := Command{
		name: 'ngc'
		description: 'Nginx Configurator helps you quickly create users and host configurations for your nginx-powered sites.'
		version: '0.0.1'
		disable_flags: true
		commands: [
			Command{
				name: 'add'
				description: 'Configures a new user and domain.'
				pre_execute: welcome
				execute: add_domain
			},
		]
	}
	app.parse(os.args)
}

fn welcome(command Command) {
	println(term.green(term.bold('Nginx Configurator: ' + command.name)))
	preflight()
}

fn preflight() {
	println(term.bright_blue('▷ Running preflight checks…'))
	assert exists_in_system_path('nginx')
	assert exists_in_system_path('certbot')
	nginx_test := exec('nginx -version') or { panic('WHOOPS') }
	certbot_test := exec('certbot --version') or { panic('WHOOPS') }
	assert nginx_test.exit_code == 0
	assert certbot_test.exit_code == 0
	println(term.bright_green('✔ Preflight checks complete.'))
}

struct DomainConfig {
	domain      string [required]
	skip_dns    bool   [required]
	www_server  bool   [required]
	public_root string [required]
	index       string [required]
}

fn add_domain(command Command) {
	config := DomainConfig{
		domain: ask(message: 'user and domain name', required: true)
		skip_dns: confirm(message: 'skip dns and certbot?', default: false)
		www_server: confirm(message: 'add a www. server and redirect?', default: false)
		public_root: ask(message: 'public root directory', default: 'public')
		index: ask(message: 'index filename', default: 'index.php')
	}
	println(config.str())
}

// type FN_ptr_task = fn (voidptr)
// struct Task {
// mut:
// 	fn_to_exec FN_ptr_task
// 	data       byteptr
// }
// fn task_new() &Task {
// 	mut local_task := &Task{}
// 	local_task.fn_to_exec = voidptr(0)
// 	local_task.data = byteptr(0)
// 	return local_task
// }
// task.fn_to_exec = proxy_radiance	// proxy_radiance            is the function you need to run
// call_fn := task.fn_to_exec	// extract function's pointer
// call_fn(task.data)
// call function with a pointer to structure containing actual parameters
