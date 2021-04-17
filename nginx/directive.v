module nginx

pub struct Directive {
	name      string
mut:
	arguments []string
	block     []Directive
}

pub fn (mut this Directive) block(directive Directive) {
	this.block << directive
}

pub fn (mut this Directive) instruction(name string, arguments ...string) {
	this.block << Directive{
		name: name
		arguments: arguments
	}
}

pub fn (mut this Directive) listen(ports ...string) {
	this.instruction('listen', ...ports)
}

pub fn (mut this Directive) server_name(name string) {
	this.instruction('server_name', name)
}

pub fn (mut this Directive) root(root string) {
	this.instruction('root', root)
}

pub fn (mut this Directive) index(index ...string) {
	this.instruction('index', ...index)
}

pub fn (mut this Directive) error_page(code string, path string) {
	this.instruction('index', code, path)
}

pub fn (mut this Directive) charset(charset string) {
	this.instruction('charset', charset)
}

pub fn (mut this Directive) access_log(path string) {
	this.instruction('access_log', path)
}

pub fn (mut this Directive) error_log(path string) {
	this.instruction('error_log', path)
}

pub fn (mut this Directive) log_not_found(path string) {
	this.instruction('log_not_found', path)
}

pub fn (mut this Directive) add_header(fragments ...string) {
	this.instruction('add_header', ...fragments)
}
pub fn (mut this Directive) return_with_status(code string, value string) {
	this.instruction('return', code, value)
}

pub fn (mut this Directive) always_add_header(fragments ...string) {
	mut props := fragments.clone()
	props << 'always'
	this.add_header(...props)
}

pub fn (mut this Directive) gzip(mode string) {
	this.instruction('gzip', mode)
}

pub fn (mut this Directive) gzip_vary(mode string) {
	this.instruction('gzip_vary', mode)
}

pub fn (mut this Directive) gzip_proxied(mode string) {
	this.instruction('gzip_proxied', mode)
}

pub fn (mut this Directive) gzip_comp_level(level string) {
	this.instruction('gzip_comp_level', level)
}

pub fn (mut this Directive) gzip_types(types ...string) {
	this.instruction('gzip_types', ...types)
}

pub fn (mut this Directive) try_files(try ...string) {
	this.instruction('try_files', ...try)
}

pub fn (mut this Directive) deny(mode string) {
	this.instruction('deny', mode)
}

pub fn (mut this Directive) expires(after string) {
	this.instruction('expires', after)
}

pub fn (this Directive) compile(indent int) string {
	mut out := this.name
	if this.name.len > 0 && this.arguments.len > 0 {
		out += ' ${this.arguments.join(' ')}'
	}
	if this.block.len > 0 {
		if this.name.len == 0 {
			whitespace := '  '.repeat(indent).replace_once('  ', '')
			for block in this.block {
				out += '$whitespace${block.compile(indent)}\n\n'
			}
		} else {
			out += ' {\n'
			whitespace := '  '.repeat(indent)
			for block in this.block {
				out += '$whitespace${block.compile(indent * 2)}\n'
			}
			out += '${whitespace.replace_once('  ', '')}}'
		}
	} else {
		out += ';'
	}
	return out.trim_space()
}
