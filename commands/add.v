module commands

import cli { Command }
import structures { Domain }
import helpers { ask, confirm }

pub fn add() Command {
	return Command{
		name: 'add'
		description: 'Configures a new user and domain.'
		pre_execute: welcome
		execute: add_domain
	}
}

fn add_domain(command Command) {
	config := Domain{
		name: ask(message: 'user and domain name', required: true)
		skip_dns: confirm(message: 'skip dns and certbot?', default: false)
		www_server: confirm(message: 'add a www. server and redirect?', default: false)
		public_root: ask(message: 'public root directory', default: 'public')
		index: ask(message: 'index filename', default: 'index.php')
	}
	println(config.str())
}
