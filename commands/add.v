module commands

import cli { Command }
import structures { AddDomainFlow }
import term

pub fn add() Command {
	return Command{
		name: 'add'
		description: 'add a new user and nginx server'
		pre_execute: welcome
		execute: add_domain
	}
}

fn add_domain(command Command) {
	mut flow := AddDomainFlow{}
	flow.acquire_domain_config()
	if !flow.domain.skip_dns {
		flow.check_domain_dns()
		flow.check_server_dns()
	} else {
		println(term.yellow(term.bold('you have chosen to ignore dns-related tasks - domain verification and certbot will be skipped.')))
	}
	flow.configure()
	flow.confirm()
	flow.create_user()
	flow.create_nginx_configuration()
	flow.complete()
}
