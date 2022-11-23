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
    usage: '<name>'
  }
}

fn add_domain(command Command)! {
  mut flow := AddDomainFlow{}

  flow.acquire_domain_config()

  if flow.domain.skip_dns {
    println(term.yellow(term.bold(
      'you have chosen to ignore dns-related tasks - domain verification and certbot will be skipped.'
    )))
  } else {
    flow.check_domain_dns()
    flow.check_server_dns()
  }

  flow.configure()
  flow.confirm_flow()
  flow.create_user()
  flow.set_basic_permissions()
  flow.create_nginx_log_directory()
  flow.create_nginx_configuration()

  if !flow.skip_certbot {
    flow.acquire_certbot_email()
    flow.run_certbot()
  }

  flow.test_and_reload()

  println(term.green('done!'))
}
