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

pub fn (mut this Directive) instruction(name string, arguments []string) {
	this.block << Directive{
		name: name
		arguments: arguments
	}
}

pub fn (this Directive) compile(indent int) string {
	mut out := this.name
	if this.name.len > 0 && this.arguments.len > 0 {
		out += ' ${this.arguments.join(' ')}'
	}
	if this.block.len > 0 {
		if this.name.len == 0 {
			whitespace := '	'.repeat(indent).replace_once('	', '')
			for block in this.block {
				out += '$whitespace${block.compile(indent)}\n\n'
			}
		} else {
			out += ' {\n'
			whitespace := '	'.repeat(indent)
			for block in this.block {
				out += '$whitespace${block.compile(indent * 2)}\n'
			}
			out += '${whitespace.replace_once('	', '')}}'
		}
	} else {
		out += ';'
	}
	return out.trim_space()
}
