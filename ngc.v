import term
import os { args }
import cli { Command }
import commands { add }

fn main() {
	term.clear()
	mut app := Command{
		name: 'ngc'
		description: 'Nginx Configurator helps you quickly create users and host configurations for your nginx-powered sites.'
		version: '0.0.1'
		disable_flags: true
		commands: [add()]
	}
	app.parse(args)
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
