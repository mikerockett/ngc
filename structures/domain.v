module structures

import helpers { ask, confirm, validate_fqdn }
import net.http
import os
import term
import nginx { Directive }

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
				return validate_fqdn(input), 'not a valid domain name'
			}
		)
		skip_dns: confirm(message: 'skip dns and certbot?', default: false)
		www_server: confirm(message: 'add a www. server with redirect?', default: false)
		public_root: ask(
			message: 'public root directory ${['public', 'dist', 'web'].join(', ')}'
			default: 'public'
			validator: fn (input string) (bool, string) {
				valids := ['public', 'dist', 'web']
				return input in valids, 'must be one of ${valids.join(', ')}'
			}
		)
		index: ask(message: 'index filename', default: 'index.php')
		shell: ask(message: 'default user shell', default: current_shell_result.output.trim_space())
	}
}

pub fn (mut this AddDomainFlow) check_domain_dns() {
	println(term.bright_blue('→ checking domain dns…'))
	result := os.exec('dig $this.domain.name +short') or {
		eprintln(term.red('unable to do a dns lookup for $this.domain.name – are you connected?'))
		exit(1)
	}
	if result.output.trim_space() == '' {
		eprintln(term.red('dns lookup yielded an empty response - $this.domain.name probably doesn’t exist.'))
		exit(1)
	}
	this.domain_dns = result.output.trim_space()
}

pub fn (mut this AddDomainFlow) check_server_dns() {
	println(term.bright_blue('→ checking server dns…'))
	result := http.get('https://icanhazip.com/') or {
		eprintln(term.red('unable to do a dns lookup for the server – are you connected?'))
		exit(1)
	}
	this.server_dns = result.text.trim_space()
}

fn get_nginx_configuration_file() string {
	result := os.exec(r"nginx -V 2>&1 | grep -o '\-\-conf-path=\(.*conf\)' | cut -d '=' -f2") or {
		eprintln(term.red('unable to obtain nginx configuration path'))
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
		println('• server dns: ${term.dim(this.server_dns)}')
		println('• domain dns: ${term.dim(this.domain_dns)}')
		match this.server_dns == this.domain_dns {
			true {
				println('✔ domain points to server')
			}
			false {
				println(term.red('⨉ domain doesn’t point to server, skipping certbot'))
				this.skip_certbot = true
			}
		}
	}
	println('- user home directory: ${term.dim(this.home_directory)}')
	println('- nginx config file path: ${term.dim(this.nginx_configuration_file)}')
	println('- nginx server config file path: ${term.dim(this.nginx_server_configuration_file)}')
	println('- nginx log file base path: ${term.dim(this.nginx_log_file_base_path)}')
	println('- try files mode: ${term.dim(this.nginx_try_files_mode)}')
	proceed := confirm(
		message: term.bright_green('happy with all of the above and proceed?')
		default: true
	)
	if !proceed {
		println(term.yellow('- cancelled'))
		exit(0)
	}
}

pub fn (mut this AddDomainFlow) create_user() {
	user_exists := os.exec('id -u $this.domain.name') or {
		eprintln(term.red('unable to id user $this.domain.name'))
		eprintln(err)
		exit(1)
	}
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

const (
	csp        = '"default-src \'self\' http: https: data: blob: \'unsafe-inline\'"'
	gzip_types = ['text/plain', 'text/css', 'text/xml', 'application/json', 'application/javascript',
		'application/rss+xml', 'application/atom+xml', 'image/svg+xml']
)

pub fn (mut this AddDomainFlow) create_nginx_configuration() {
	filename := this.nginx_server_configuration_file
	if os.is_file(filename) {
		println(term.yellow('$filename exists, removing…'))
		os.rm(filename) or {
			eprintln(term.red('unable to delete existing $filename'))
			exit(1)
		}
	}
	println(term.bright_blue('→ opening $filename'))
	mut file := os.open_file(filename, 'w+') or {
		eprintln(term.red('unable to create $filename'))
		eprintln(err)
		exit(1)
	}
	mut conf := Directive{}
	println(term.dim('- preparing main server'))
	conf.block(this.nginx_main_server())
	if this.domain.www_server {
		println(term.dim('- preparing www server'))
		conf.block(this.nginx_www_server())
	}
	println(term.dim('- compiling'))
	compiled := conf.compile(1)
	println(term.dim('- writing file'))
	file.write_str(compiled)
	file.close()
	println(term.green('✔ nginx config written to file'))
}

pub fn (this AddDomainFlow) nginx_main_server() Directive {
	mut server := Directive{
		name: 'server'
	}
	server.instruction('listen', ['80'])
	server.instruction('listen', ['[::]:80'])
	server.instruction('server_name', [this.domain.name])
	server.instruction('root', [os.join_path(this.home_directory, 'www', this.domain.public_root)])
	server.instruction('index', [this.domain.index])
	server.instruction('error_page', ['404', '/$this.domain.index'])
	server.instruction('charset', ['utf-8'])
	server.instruction('access_log', ['$this.nginx_log_file_base_path/access.log'])
	server.instruction('error_log', ['$this.nginx_log_file_base_path/error.log'])
	server.instruction('add_header', ['X-Frame-Options', '"SAMEORIGIN"', 'always'])
	server.instruction('add_header', ['X-XSS-Protection', '"1; mode=block"', 'always'])
	server.instruction('add_header', ['X-Content-Type-Options', '"nosniff"', 'always'])
	server.instruction('add_header', ['Referrer-Policy', '"no-referrer-when-downgrade"', 'always'])
	server.instruction('add_header', ['Content-Security-Policy', csp, 'always'])
	server.instruction('gzip', ['on'])
	server.instruction('gzip_vary', ['on'])
	server.instruction('gzip_proxied', ['any'])
	server.instruction('gzip_comp_level', ['6'])
	server.instruction('gzip_types', gzip_types)
	server.block(this.nginx_main_location())
	server.block(this.nginx_exclusion_location())
	server.block(this.nginx_well_known_location())
	server.block(this.nginx_files_a_location())
	server.block(this.nginx_files_b_location())
	if this.domain.index.ends_with('.php') {
		server.block(this.nginx_php_location())
	}
	return server
}

pub fn (this AddDomainFlow) nginx_www_server() Directive {
	mut server := Directive{
		name: 'server'
	}
	server.instruction('server_name', ['www.$this.domain.name'])
	server.instruction('return', ['301', '\$scheme://$this.domain.name' + '\$request_uri'])
	return server
}

pub fn (this AddDomainFlow) nginx_main_location() Directive {
	mut main_location := Directive{
		name: 'location'
		arguments: ['/']
	}
	main_location.instruction('try_files', ['\$uri', '\$uri/', '/$this.nginx_try_files_mode'])
	return main_location
}

pub fn (this AddDomainFlow) nginx_exclusion_location() Directive {
	mut location := Directive{
		name: 'location'
		arguments: ['~', '/(favicon\.ico|robots\.txt)']
	}
	location.instruction('access_log', ['off'])
	location.instruction('log_not_found', ['off'])
	return location
}

pub fn (this AddDomainFlow) nginx_well_known_location() Directive {
	mut location := Directive{
		name: 'location'
		arguments: ['~', '/\\.(?!well-known).*']
	}
	location.instruction('deny', ['all'])
	return location
}

pub fn (this AddDomainFlow) nginx_files_a_location() Directive {
	mut location := Directive{
		name: 'location'
		arguments: ['~*', '.(?:css(.map)?|js(.map)?|jpe?g|png|gif|ico|cur|heic|webp|tiff?|mp3|m4a|aac|ogg|midi?|wav|mp4|mov|webm|mpe?g|avi|ogv|flv|wmv)$']
	}
	location.instruction('expires', ['7d'])
	location.instruction('access_log', ['off'])
	return location
}

pub fn (this AddDomainFlow) nginx_files_b_location() Directive {
	mut location := Directive{
		name: 'location'
		arguments: ['~*', '.(?:svgz?|ttf|ttc|otf|eot|woff2?)$']
	}
	location.instruction('add_header', ['Access-Control-Allow-Origin', '"*"'])
	location.instruction('expires', ['7d'])
	location.instruction('access_log', ['off'])
	return location
}

pub fn (this AddDomainFlow) nginx_php_location() Directive {
	mut location := Directive{
		name: 'location'
		arguments: ['~', '.php$']
	}
	location.instruction('include', ['fastcgi_params'])
	location.instruction('fastcgi_pass', ['unix:/var/run/php/php-fpm.sock'])
	location.instruction('fastcgi_index', [this.domain.index])
	location.instruction('fastcgi_buffers', ['8', '16k'])
	location.instruction('fastcgi_buffer_size', ['32k'])
	location.instruction('fastcgi_param', ['DOCUMENT_ROOT', '\$realpath_root'])
	location.instruction('fastcgi_param', ['SCRIPT_FILENAME', '\$realpath_root\$fastcgi_script_name'])
	return location
}
