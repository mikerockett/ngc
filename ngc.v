import os { args }
import cli { Command }
import commands { add }
import nginx { Directive }

fn main() {
	mut app := Command{
		name: 'ngc'
		description: 'Nginx Configurator helps you quickly create users and host configurations for your nginx-powered sites.'
		version: '0.0.1'
		disable_flags: true
		commands: [add()]
	}
	app.parse(args)
}
