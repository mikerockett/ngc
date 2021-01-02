module commands

import cli { Command }
import structures { Domain }
import helpers { ask, confirm }
import term
import os
import net.http

pub fn add() Command {
	return Command{
		name: 'add'
		description: 'Configures a new user and domain.'
		pre_execute: welcome
		execute: add_domain
	}
}

struct AddDomainFlow {
mut:
	domain                          Domain
	domain_dns                      string
	server_dns                      string
	home_directory                  string
	nginx_configuration_file        string
	nginx_server_configuration_file string
	nginx_log_file_base_path string
}

fn add_domain(command Command) {
	mut flow := AddDomainFlow{}
	flow.acquire_domain_config()
	if !flow.domain.skip_dns {
		flow.check_domain_dns()
		flow.check_server_dns()
	} else {
		println(term.yellow(term.bold('You have chosen to ignore DNS related tasks. As such, there will be no domain verification, and certbot will not be run.')))
	}
	flow.configure()
	flow.confirm()
}

fn (mut this AddDomainFlow) acquire_domain_config() {
	this.domain = Domain{
		name: ask(message: 'user and domain name', required: true)
		skip_dns: confirm(message: 'skip dns and certbot?', default: false)
		www_server: confirm(message: 'add a www. server and redirect?', default: false)
		public_root: ask(message: 'public root directory', default: 'public')
		index: ask(message: 'index filename', default: 'index.php')
		shell: ask(message: 'default user shell', default: '/usr/bin/bash')
	}
}

fn (mut this AddDomainFlow) check_domain_dns() {
	result := os.exec('dig $this.domain.name +short') or {
		panic('Unable to do a DNS lookup for $this.domain.name – are you connected?')
	}
	this.domain_dns = result.output.trim_space()
}

fn (mut this AddDomainFlow) check_server_dns() {
	result := http.get('https://icanhazip.com/') or {
		panic('Unable to do a DNS lookup for the server – are you connected?')
	}
	this.server_dns = result.text.trim_space()
}

fn (mut this AddDomainFlow) configure() {
	this.home_directory = '/home/$this.domain.name'
	this.nginx_configuration_file = get_nginx_configuration_file()
	this.nginx_server_configuration_file = os.join_path(os.dir(this.nginx_configuration_file),
		'conf.d', '${this.domain.name}.conf')
	this.nginx_log_file_base_path = os.join_path(this.home_directory, 'log/nginx')
}

fn get_nginx_configuration_file() string {
	result := os.exec(r"nginx -V 2>&1 | grep -o '\-\-conf-path=\(.*conf\)' | cut -d '=' -f2") or {
		panic('Unable to obtain nginx configuration path')
	}
	config_file := os.real_path(result.output.trim_space())
	if !os.is_file(config_file) {
		eprintln(term.red('nginx configuration is not a file, or is otherwise unreadable'))
		exit(1)
	}
	return config_file
}

fn (this AddDomainFlow) confirm() {
	println(term.green('configurator has everything it needs to add a new domain,\nand just needs your confirmation on some other info it gathered:'))
	if !this.domain.skip_dns {
		println('— domain dns: ' + term.dim(this.domain_dns))
		println('— server dns: ' + term.dim(this.server_dns))
	}
	println('— user home directory: ' + term.dim(this.home_directory))
	println('— nginx config file path: ' + term.dim(this.nginx_configuration_file))
	println('— nginx server config file path: ' + term.dim(this.nginx_server_configuration_file))
	println('— nginx log file base path: ' + term.dim(this.nginx_log_file_base_path))
	if !confirm(
		message: term.bright_green('happy with all of the above and proceed?')
		default: true
	) {
		exit(0)
	}
}
