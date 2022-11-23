module structures

import helpers { ask, confirm, validate_fqdn, validate_email }
import os
import term
import nginx { Directive }

pub struct Domain {
pub:
  name string [required]
  skip_dns bool [required]
  www_server bool[required]
  repo_directory string
  public_root string [required]
  index string [required]
  shell string [required]
}

pub struct AddDomainFlow {
pub mut:
  domain Domain
  domain_dns string
  home_directory string
  nginx_configuration_file string
  nginx_log_file_base_path string
  nginx_server_configuration_file string
  nginx_try_files_mode string
  server_dns string
  skip_certbot bool
  certbot_email string
}

pub fn (mut this AddDomainFlow) acquire_domain_config() {
  mut current_shell_result := os.execute(r'echo $SHELL')

  if current_shell_result.exit_code != 0 {
    current_shell_result = os.Result{0, '/usr/bin/bash'}
  }

  this.domain = Domain{
    name: ask(
      message: 'user and domain name'
      default: if os.args.len == 3 { os.args[2] } else { '' }
      required: os.args.len < 3
      validator: fn (input string) (bool, string) {
        return validate_fqdn(input), 'not a valid domain name'
      }
    )

    skip_dns: confirm(message: 'skip dns and certbot?', default: false)
    www_server: confirm(message: 'add a www. server with redirect?', default: false)

    repo_directory: ask(
      message: 'repo directory (one of ${['www', 'repo', 'public_html'].join(', ')})'
      default: 'www'
      validator: fn (input string) (bool, string) {
        valids := ['www', 'repo', 'public_html']
        return input in valids, 'must be one of ${valids.join(', ')}'
      }
    )

    public_root: ask(
      message: 'public root directory (one of ${['public', 'dist', 'web'].join(', ')})'
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

  result := os.execute('dig +short $this.domain.name')

  if result.exit_code != 0 {
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

  result := os.execute('dig +short myip.opendns.com @resolver1.opendns.com')

  if result.exit_code != 0 {
    eprintln(term.red('unable to do a dns lookup for the server – are you connected?'))
    exit(1)
  }

  this.server_dns = result.output.trim_space()
}

fn get_nginx_configuration_file() string {
  result := os.execute(r"nginx -V 2>&1 | grep -o '\-\-conf-path=\(.*conf\)' | cut -d '=' -f2")

  if result.exit_code != 0 {
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

  this.nginx_server_configuration_file = os.join_path(
    os.dir(this.nginx_configuration_file),
    'conf.d',
    '${this.domain.name}.conf'
  )

  this.nginx_log_file_base_path = os.join_path(this.home_directory, 'log/nginx')

  this.nginx_try_files_mode = match this.domain.index.after('.') {
    'php' { '$this.domain.index?\$query_string' }
    else { this.domain.index }
  }
}

pub fn (mut this AddDomainFlow) confirm_flow() {
  println(term.green('configurator has everything it needs to add a new domain,\nand just needs your confirmation on some other info it gathered:'))

  if !this.domain.skip_dns {
    println('• server dns: ${term.dim(this.server_dns)}')
    println('• domain dns: ${term.dim(this.domain_dns)}')

    this.skip_certbot = this.server_dns != this.domain_dns

    match this.skip_certbot {
      true {
        println(term.red('⨉ domain doesn’t point to server, certbot will be skipped'))
      }
      false {
        println('✔ domain points to server, certbot will be run at the end')
      }
    }
  }

  println('+ user home directory: ${term.dim(this.home_directory)}')
  println('+ repo directory: ${term.dim(this.domain.repo_directory)}')
  println('+ nginx config file path: ${term.dim(this.nginx_configuration_file)}')
  println('+ nginx server config file path: ${term.dim(this.nginx_server_configuration_file)}')
  println('+ nginx log file base path: ${term.dim(this.nginx_log_file_base_path)}')
  println('+ try files mode: ${term.dim(this.nginx_try_files_mode)}')

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
  user_exists_result := os.execute('id -u $this.domain.name')

  if user_exists_result.exit_code == 0 {
    println(term.yellow('→ user $this.domain.name already exists'))
    return
  }

  println(term.bright_green('→ user $this.domain.name does not exist, creating…'))

  result := os.execute('useradd -m $this.domain.name -s $this.domain.shell')

  if result.exit_code != 0 {
    eprintln(term.red('unable to create user.'))
    exit(1)
  }

  println(term.green('✔ user created'))
}

pub fn (mut this AddDomainFlow) set_basic_permissions() {
  chmod_command := 'chmod -R 770 $this.home_directory'
  chmod_result := os.execute(chmod_command)

  if chmod_result.exit_code != 0 {
    eprintln(term.red('unable to run chmod, please do this yourself with: $chmod_command'))
  }

  chown_command := 'chown -R $this.domain.name:nginx'
  chown_result := os.execute(chown_command)

  if chown_result.exit_code != 0 {
    eprintln(term.red('unable to run chown, please do this yourself with: $chown_command'))
  }
}

const (
  gzip_types = [
    'text/plain',
    'text/css',
    'text/xml',
    'application/json',
    'application/javascript',
    'application/rss+xml',
    'application/atom+xml',
    'image/svg+xml'
  ]
)

pub fn (mut this AddDomainFlow) create_log_directory() {
  os.mkdir_all(this.nginx_log_file_base_path) or {
    eprintln(term.red('unable to create log directory'))
    eprintln(err)
    exit(1)
  }
}

pub fn (mut this AddDomainFlow) create_nginx_configuration() {
  filename := this.nginx_server_configuration_file

  mut conf := Directive{}

  println(term.dim('- preparing main server'))

  conf.block(this.nginx_main_server())

  if this.domain.www_server {
    println(term.dim('- preparing www server'))
    conf.block(this.nginx_www_server())
  }

  println(term.dim('- compiling'))

  compiled := conf.compile(1)

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

  println(term.dim('- writing file'))

  file.write_string(compiled) or {
    eprintln(term.red('unable to create config'))
    file.close()
    exit(1)
  }

  file.close()

  println(term.green('✔ nginx config written to file'))
}

pub fn (this AddDomainFlow) nginx_main_server() Directive {
  mut server := Directive{
    name: 'server'
  }

  server.listen('80')
  server.listen('[::]:80')
  server.server_name(this.domain.name)
  server.root(os.join_path(this.home_directory, this.domain.repo_directory, this.domain.public_root))
  server.index(this.domain.index)
  server.error_page('404', '/$this.domain.index')
  server.charset('utf-8')
  server.access_log(os.join_path(this.nginx_log_file_base_path, 'access.log'))
  server.error_log(os.join_path(this.nginx_log_file_base_path, 'error.log'))
  server.always_add_header('X-Frame-Options', '"SAMEORIGIN"')
  server.always_add_header('X-XSS-Protection', '"1; mode=block"')
  server.always_add_header('X-Content-Type-Options', '"nosniff"')
  server.always_add_header('Referrer-Policy', '"no-referrer-when-downgrade"')
  server.always_add_header('Content-Security-Policy', '"default-src \'self\' http: https: data: blob: \'unsafe-inline\'"')
  server.always_add_header('Permissions-Policy', 'interest-cohort=()')
  server.gzip('on')
  server.gzip_vary('on')
  server.gzip_proxied('any')
  server.gzip_comp_level('6')
  server.gzip_types(...gzip_types)
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

  server.server_name('www.$this.domain.name')
  server.return_with_status('301', '\$scheme://$this.domain.name' + '\$request_uri')

  return server
}

pub fn (this AddDomainFlow) nginx_main_location() Directive {
  mut main_location := Directive{
    name: 'location'
    arguments: ['/']
  }

  main_location.try_files('\$uri', '\$uri/', '/$this.nginx_try_files_mode')

  return main_location
}

pub fn (this AddDomainFlow) nginx_exclusion_location() Directive {
  mut location := Directive{
    name: 'location'
    arguments: ['~', '/(favicon\.ico|robots\.txt)']
  }

  location.access_log('off')
  location.log_not_found('off')

  return location
}

pub fn (this AddDomainFlow) nginx_well_known_location() Directive {
  mut location := Directive{
    name: 'location'
    arguments: ['~', '/\\.(?!well-known).*']
  }

  location.deny('all')

  return location
}

pub fn (this AddDomainFlow) nginx_files_a_location() Directive {
  mut location := Directive{
    name: 'location'
    arguments: ['~*', '.(?:css(.map)?|js(.map)?|jpe?g|png|gif|ico|cur|heic|webp|tiff?|mp3|m4a|aac|ogg|midi?|wav|mp4|mov|webm|mpe?g|avi|ogv|flv|wmv)$']
  }

  location.expires('7d')
  location.access_log('off')

  return location
}

pub fn (this AddDomainFlow) nginx_files_b_location() Directive {
  mut location := Directive{
    name: 'location'
    arguments: ['~*', '.(?:svgz?|ttf|ttc|otf|eot|woff2?)$']
  }

  location.add_header('Access-Control-Allow-Origin', '"*"')
  location.expires('7d')
  location.access_log('off')

  return location
}

pub fn (this AddDomainFlow) nginx_php_location() Directive {
  mut location := Directive{
    name: 'location'
    arguments: ['~', '.php$']
  }

  location.instruction('include', 'fastcgi_params')
  location.instruction('fastcgi_pass', 'unix:/var/run/php/php-fpm.sock')
  location.instruction('fastcgi_index', this.domain.index)
  location.instruction('fastcgi_buffers', '8', '16k')
  location.instruction('fastcgi_buffer_size', '32k')
  location.instruction('fastcgi_param', 'DOCUMENT_ROOT', '\$realpath_root')
  location.instruction('fastcgi_param', 'SCRIPT_FILENAME', '\$realpath_root\$fastcgi_script_name')

  return location
}

pub fn (mut this AddDomainFlow) acquire_certbot_email() {
  this.certbot_email = ask(
    message: 'email address for certbot'
    required: true
    validator: fn (input string) (bool, string) {
      return validate_email(input), 'not a valid email address'
    }
  )
}

pub fn (mut this AddDomainFlow) run_certbot() {
  mut le_domains := [this.domain.name]

  if this.domain.www_server {
    le_domains << 'www.$this.domain.name'
  }

  command := 'certbot --quiet --nginx --agree-tos --redirect --email $this.certbot_email --domain ${le_domains.join(',')}'
  result := os.execute(command)

  if result.exit_code != 0 {
    eprintln(term.red('unable to run certbot – please do this yourself: ${command}'))
    exit(1)
  }
}

pub fn (mut this AddDomainFlow) test_and_reload() {
  test_command := 'nginx -t'
  test_result := os.execute(test_command)

  if test_result.exit_code != 0 {
    eprintln(term.red('nginx syntax failed, please check and correct, then run: $test_command'))
    exit(1)
  }

  println(term.green('✔ nginx syntax ok'))

  reload_command := 'systemctl reload nginx'
  reload_result := os.execute(reload_command)

  if reload_result.exit_code != 0 {
    eprintln(term.red('unable to reload nginx – please do this yourself with: $reload_command'))
    exit(1)
  }

  println(term.green('✔ nginx reloaded'))
}
