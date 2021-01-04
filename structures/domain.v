module structures

import helpers { ask, confirm, validate_fqdn }
import net.http
import os
import term

pub struct Domain {
pub:
	name        string [required]
	skip_dns    bool   [required]
	www_server  bool   [required]
	public_root string [required]
	index       string [required]
	shell       string [required]
}

pub struct AddDomainFlow {
pub mut:
	domain                          Domain
	domain_dns                      string
	home_directory                  string
	nginx_configuration_file        string
	nginx_log_file_base_path        string
	nginx_server_configuration_file string
	nginx_try_files_mode            string
	server_dns                      string
	skip_certbot                    bool
}

pub fn (mut this AddDomainFlow) acquire_domain_config() {
	current_shell_result := os.exec(r'echo $SHELL') or { os.Result{0, '/usr/bin/bash'} }
	this.domain = Domain{
		name: ask(
			message: 'user and domain name'
			required: true
			validator: fn (input string) (bool, string) {
				return validate_fqdn(input), 'Not a valid domain name'
			}
		)
		skip_dns: confirm(message: 'skip dns and certbot?', default: false)
		www_server: confirm(message: 'add a www. server with redirect?', default: false)
		public_root: ask(
			message: 'public root directory ${['public', 'dist', 'web'].join(', ')}'
			default: 'public'
			validator: fn (input string) (bool, string) {
				valids := ['public', 'dist', 'web']
				return input in valids, 'Must be one of ${valids.join(', ')}'
			}
		)
		index: ask(message: 'index filename', default: 'index.php')
		shell: ask(message: 'default user shell', default: current_shell_result.output.trim_space())
	}
}

pub fn (mut this AddDomainFlow) check_domain_dns() {
	println(term.bright_blue('→ checking domain dns…'))
	result := os.exec('dig $this.domain.name +short') or {
		eprintln(term.red('Unable to do a DNS lookup for $this.domain.name – are you connected?'))
		return
	}
	this.domain_dns = result.output.trim_space()
}

pub fn (mut this AddDomainFlow) check_server_dns() {
	println(term.bright_blue('→ checking server dns…'))
	result := http.get('https://icanhazip.com/') or {
		eprintln(term.red('Unable to do a DNS lookup for the server – are you connected?'))
		return
	}
	this.server_dns = result.text.trim_space()
}

fn get_nginx_configuration_file() string {
	result := os.exec(r"nginx -V 2>&1 | grep -o '\-\-conf-path=\(.*conf\)' | cut -d '=' -f2") or {
		eprintln(term.red('Unable to obtain nginx configuration path'))
		exit(1)
	}
	config_file := os.real_path(result.output.trim_space())
	if !os.is_file(config_file) {
		eprintln(term.red('nginx configuration is not a file, or is otherwise unreadable'))
		exit(1)
	}
	return config_file
}

pub fn (mut this AddDomainFlow) configure() {
	this.home_directory = '/home/$this.domain.name'
	this.nginx_configuration_file = get_nginx_configuration_file()
	this.nginx_server_configuration_file = os.join_path(os.dir(this.nginx_configuration_file),
		'conf.d', '${this.domain.name}.conf')
	this.nginx_log_file_base_path = os.join_path(this.home_directory, 'log/nginx')
	this.nginx_try_files_mode = match this.domain.index.after('.') {
		'php' { '$this.domain.index?\$query_string' }
		else { this.domain.index }
	}
}

pub fn (mut this AddDomainFlow) confirm() {
	println(term.green('configurator has everything it needs to add a new domain,\nand just needs your confirmation on some other info it gathered:'))
	if !this.domain.skip_dns {
		println('— server dns: ' + term.dim(this.server_dns))
		println('— domain dns: ' + term.dim(this.domain_dns))
		match this.server_dns == this.domain_dns {
			true {
				println('✔ domain points to server')
			}
			false {
				println(term.red('⨉ domain doesn’t point to server – will skip certbot'))
				this.skip_certbot = true
			}
		}
	}
	println('— user home directory: ' + term.dim(this.home_directory))
	println('— nginx config file path: ' + term.dim(this.nginx_configuration_file))
	println('— nginx server config file path: ' + term.dim(this.nginx_server_configuration_file))
	println('— nginx log file base path: ' + term.dim(this.nginx_log_file_base_path))
	println('— try files mode: ' + term.dim(this.nginx_try_files_mode))
	proceed := confirm(
		message: term.bright_green('happy with all of the above and proceed?')
		default: true
	)
	if !proceed {
		println(term.yellow('◂ Bye…'))
		exit(0)
	}
}

pub fn (mut this AddDomainFlow) create_user() {
	user_exists := os.exec('id -u $this.domain.name') or { panic('Unable to id user') }
	if user_exists.exit_code == 0 {
		println(term.yellow('→ user $this.domain.name already exists'))
		return
	}
	println(term.bright_green('→ user $this.domain.name does not exist, creating…'))
	result := os.exec('useradd -m $this.domain.name -s $this.domain.shell') or {
		eprintln(term.red(err))
		exit(1)
	}
	println(result)
}
