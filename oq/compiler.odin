package OQ

import "core:fmt"
import "core:strconv"

U8_COUNT :: 256
U16_MAX :: 65535

ParseFn :: #type proc(can_assign: bool)

Parser :: struct {
	current:    Token,
	previous:   Token,
	had_error:  bool,
	panic_mode: bool,
}

Precedence :: enum {
	NONE,
	ASSIGNMENT,
	OR,
	AND,
	EQUALITY,
	COMPARISON,
	TERM,
	FACTOR,
	UNARY,
	CALL,
	PRIMARY,
}

ParseRule :: struct {
	prefix:     ParseFn,
	infix:      ParseFn,
	precedence: Precedence,
}

Compiler :: struct {
	locals:      [U8_COUNT]Local,
	local_count: int,
	scope_depth: int,
}

Local :: struct {
	name:  Token,
	depth: int,
}

@(rodata)
rules := [TokenType]ParseRule {
	.LEFT_PAREN    = {grouping, nil, .NONE},
	.RIGHT_PAREN   = {nil, nil, .NONE},
	.LEFT_BRACE    = {nil, nil, .NONE},
	.RIGHT_BRACE   = {nil, nil, .NONE},
	.COMMA         = {nil, nil, .NONE},
	.DOT           = {nil, nil, .NONE},
	.MINUS         = {unary, binary, .TERM},
	.PLUS          = {nil, binary, .TERM},
	.PLUS_EQUALS   = {nil, nil, .NONE},
	.PERCENT       = {nil, binary, .TERM},
	.SEMICOLON     = {nil, nil, .NONE},
	.SLASH         = {nil, binary, .FACTOR},
	.STAR          = {nil, binary, .FACTOR},
	.CARET         = {nil, binary, .FACTOR},
	.BANG          = {unary, nil, .NONE},
	.BANG_EQUAL    = {nil, binary, .EQUALITY},
	.EQUAL         = {nil, nil, .NONE},
	.EQUAL_EQUAL   = {nil, binary, .EQUALITY},
	.GREATER       = {nil, binary, .COMPARISON},
	.GREATER_EQUAL = {nil, binary, .COMPARISON},
	.LESS          = {nil, binary, .COMPARISON},
	.LESS_EQUAL    = {nil, binary, .COMPARISON},
	.IDENTIFIER    = {variable, nil, .NONE},
	.STRING        = {string_, nil, .NONE},
	.NUMBER        = {number, nil, .NONE},
	.AND           = {nil, and_, .AND},
	.STRUCT        = {nil, nil, .NONE},
	.ELSE          = {nil, nil, .NONE},
	.FALSE         = {literal, nil, .NONE},
	.FOR           = {nil, nil, .NONE},
	.PROC          = {nil, nil, .NONE},
	.IF            = {nil, nil, .NONE},
	.NIL           = {literal, nil, .NONE},
	.OR            = {nil, or_, .OR},
	.PRINT         = {nil, nil, .NONE},
	.RETURN        = {nil, nil, .NONE},
	.SUPER         = {nil, nil, .NONE},
	.THIS          = {nil, nil, .NONE},
	.TRUE          = {literal, nil, .NONE},
	.VAR           = {nil, nil, .NONE},
	.WHILE         = {nil, nil, .NONE},
	.COLON         = {nil, nil, .NONE},
	.COLONCOLON    = {nil, nil, .NONE},
	.ERROR         = {nil, nil, .NONE},
	.EOF           = {nil, nil, .NONE},
}

parser: Parser
current: ^Compiler

compiling_chunk: ^Chunk

parser_advance :: proc() {
	parser.previous = parser.current

	for {
		parser.current = scan_token()
		if parser.current.type != .ERROR do break

		error_at_current(token_get_text(parser.current))
	}
}

init_compiler :: proc(compiler: ^Compiler) {
	compiler.local_count = 0
	compiler.scope_depth = 0
	current = compiler
}

compile :: proc(code: string, chunk: ^Chunk) -> bool {
	scanner_init(code)
	compiler: Compiler
	init_compiler(&compiler)
	compiling_chunk = chunk
	parser.had_error = false
	parser_advance()
	for !token_match(.EOF) {
		declaration()
	}
	end_compiler()
	return !parser.had_error
}

string_ :: proc(can_assign: bool) {
	emit_constant(allocate_string(parser.previous.text[1:parser.previous.length - 1]))
}

number :: proc(can_assign: bool) {
	value, ok := strconv.parse_f64(parser.previous.text)
	emit_constant(value)
}

and_ :: proc(can_assign: bool) {
	end_jump := emit_jump(u8(Op.JUMP_IF_FALSE))
	emit_byte(u8(Op.POP))
	parse_precedence(.AND)
	patch_jump(end_jump)
}

or_ :: proc(can_assign: bool) {
	else_jump := emit_jump(u8(Op.JUMP_IF_FALSE))
	end_jump := emit_jump(u8(Op.JUMP))
	patch_jump(else_jump)
	emit_byte(u8(Op.POP))

	parse_precedence(.OR)
	patch_jump(end_jump)
}

variable :: proc(can_assign: bool) {
	named_variable(&parser.previous, can_assign)
}

named_variable :: proc(name: ^Token, can_assign: bool) {
	get_op, set_op: u8
	arg, ok := resolve_local(current, name)

	if ok {
		get_op = u8(Op.GET_LOCAL)
		set_op = u8(Op.SET_LOCAL)
	} else {
		arg = identifier_constant(name)
		get_op = u8(Op.GET_GLOBAL)
		set_op = u8(Op.SET_GLOBAL)
	}

	if type, ok := token_match_any(.EQUAL, .PLUS_EQUALS); can_assign && ok {
		#partial switch type {
		case .EQUAL:
			expression()
			emit_bytes(set_op, arg)
		case .PLUS_EQUALS:
			emit_bytes(get_op, arg)
			expression()
			emit_byte(u8(Op.ADD))
			emit_bytes(set_op, arg)
		}
	} else {
		emit_bytes(get_op, arg)
	}
}

resolve_local :: proc(compiler: ^Compiler, name: ^Token) -> (u8, bool) {
	for i := compiler.local_count - 1; i >= 0; i -= 1 {
		local := &compiler.locals[i]
		if identifier_equals(name, &local.name) {
			if local.depth == -1 {
				error("Can't read local variable in its own initializer.")
			}
			return u8(i), true
		}
	}
	return 0, false
}

literal :: proc(can_assign: bool) {
	#partial switch parser.previous.type {
	case .FALSE:
		emit_byte(u8(Op.FALSE))
	case .TRUE:
		emit_byte(u8(Op.TRUE))
	case .NIL:
		emit_byte(u8(Op.NIL))
	}
}

unary :: proc(can_assign: bool) {
	operator_type := parser.previous.type

	parse_precedence(.UNARY)

	#partial switch operator_type {
	case .BANG:
		emit_byte(u8(Op.NOT))
	case .MINUS:
		emit_byte(u8(Op.NEGATE))
	case:
		return
	}
}

binary :: proc(can_assign: bool) {
	operator_type := parser.previous.type

	rule := rule_get(operator_type)
	parse_precedence(Precedence(int(rule.precedence) + 1))

	#partial switch operator_type {
	case .PLUS:
		emit_byte(u8(Op.ADD))
	case .MINUS:
		emit_byte(u8(Op.SUB))
	case .STAR:
		emit_byte(u8(Op.MUL))
	case .SLASH:
		emit_byte(u8(Op.DIV))
	case .PERCENT:
		emit_byte(u8(Op.MOD))
	case .CARET:
		emit_byte(u8(Op.POW))
	case .BANG_EQUAL:
		emit_byte(u8(Op.NOT_EQUAL))
	case .EQUAL_EQUAL:
		emit_byte(u8(Op.EQUAL))
	case .GREATER:
		emit_byte(u8(Op.GREATER))
	case .GREATER_EQUAL:
		emit_byte(u8(Op.GREATER_EQUAL))
	case .LESS:
		emit_byte(u8(Op.LESS))
	case .LESS_EQUAL:
		emit_byte(u8(Op.LESS_EQUAL))
	case:
		return
	}
}

grouping :: proc(can_assign: bool) {

	expression()
	consume(.RIGHT_PAREN, "Expect ')' after expression.")
}

expression :: proc() {
	parse_precedence(.ASSIGNMENT)
}

declaration :: proc() {
	if token_match(.VAR) {
		var_declaration()
	} else {
		statement()
	}

	if parser.panic_mode do synchronize()
}

statement :: proc() {
	if token_match(.PRINT) {
		print_statement()
	} else if token_match(.IF) {
		if_statement()
	} else if token_match(.WHILE) {
		while_statement()
	} else if token_match(.FOR) {
		for_statement()
	} else if token_match(.LEFT_BRACE) {
		begin_scope()
		block()
		end_scope()
	} else {
		expression_statement()
	}
}

if_statement :: proc() {
	expression()
	non_consume(.LEFT_BRACE, "Expect '{' block after 'if'.")

	then_jump := emit_jump(u8(Op.JUMP_IF_FALSE))
	emit_byte(u8(Op.POP))
	statement()
	else_jump := emit_jump(u8(Op.JUMP))
	patch_jump(then_jump)
	emit_byte(u8(Op.POP))

	if token_match(.ELSE) do statement()
	patch_jump(else_jump)
}

while_statement :: proc() {
	loop_start := len(current_chunk().code)

	expression()
	non_consume(.LEFT_BRACE, "Expect '{' block after 'while'.")

	exit_jump := emit_jump(u8(Op.JUMP_IF_FALSE))
	emit_byte(u8(Op.POP))
	statement()
	emit_loop(loop_start)

	patch_jump(exit_jump)
	emit_byte(u8(Op.POP))
}

for_statement :: proc() {
	begin_scope()

	if token_match(.SEMICOLON) {

	} else if token_match(.VAR) {
		var_declaration()
	} else {
		expression_statement()
	}

	loop_start := len(current_chunk().code)
	exit_jump: int = -1

	if !token_match(.SEMICOLON) {
		expression()
		consume(.SEMICOLON, "Expect ';' after loop condition.")

		exit_jump = emit_jump(u8(Op.JUMP_IF_FALSE))
		emit_byte(u8(Op.POP))
	}

	if !token_match(.LEFT_BRACE) {
		body_jump := emit_jump(u8(Op.JUMP))
		increment_start := len(current_chunk().code)
		expression()
		emit_byte(u8(Op.POP))
		non_consume(.LEFT_BRACE, "Expect '{' after for clauses.")

		emit_loop(loop_start)
		loop_start = increment_start
		patch_jump(body_jump)
	}

	statement()
	emit_loop(loop_start)

	if exit_jump != -1 {
		patch_jump(exit_jump)
		emit_byte(u8(Op.POP))
	}

	end_scope()
}

emit_loop :: proc(loop_start: int) {
	emit_byte(u8(Op.LOOP))

	offset := len(current_chunk().code) - loop_start + 2
	if offset > U16_MAX do error("Loop body too large.")

	emit_byte(u8(u16(offset >> 8) & 0xff))
	emit_byte(u8(offset & 0xff))
}

emit_jump :: proc(instruction: u8) -> int {
	emit_byte(instruction)
	emit_byte(0xff)
	emit_byte(0xff)
	return len(current_chunk().code) - 2
}

patch_jump :: proc(offset: int) {
	jump := len(current_chunk().code) - offset - 2

	if jump > U16_MAX {
		error("Too much code to jump over.")
	}

	current_chunk().code[offset] = u8((jump >> 8) & 0xff)
	current_chunk().code[offset + 1] = u8(jump & 0xff)
}

expression_statement :: proc() {
	expression()
	consume(.SEMICOLON, "Expect ';' after expression.")
	emit_byte(u8(Op.POP))
}

begin_scope :: proc() {
	current.scope_depth += 1
}

end_scope :: proc() {
	current.scope_depth -= 1

	for current.local_count > 0 &&
	    current.locals[current.local_count - 1].depth > current.scope_depth {
		emit_byte(u8(Op.POP))
		current.local_count -= 1
	}
}

block :: proc() {
	for !token_check(.RIGHT_BRACE) && !token_check(.EOF) {
		declaration()
	}
	consume(.RIGHT_BRACE, "Expect '}' after block.")
}

var_declaration :: proc() {
	global := parse_variable("Expect variable name.")

	if token_match(.EQUAL) {
		expression()
	} else {
		emit_byte(u8(Op.NIL))
	}
	consume(.SEMICOLON, "Expect ';' after variable declaration.")
	define_variable(global)
}

print_statement :: proc() {
	consume(.LEFT_PAREN, "Missing '(' after function call.")
	expression()
	consume(.RIGHT_PAREN, "Missing ')' after function call.")
	consume(.SEMICOLON, "Expect ';' after value.")
	emit_byte(u8(Op.PRINT))
}

token_match :: proc(type: TokenType) -> bool {
	if !token_check(type) do return false
	parser_advance()
	return true
}

token_match_any :: proc(types: ..TokenType) -> (TokenType, bool) {
	for type in types {
		if token_check(type) {
			parser_advance()
			return type, true
		}
	}
	return .DOT, false
}

token_check :: #force_inline proc "contextless" (type: TokenType) -> bool {
	return parser.current.type == type
}

parse_precedence :: proc(precedence: Precedence) {
	parser_advance()
	prefix_rule := rule_get(parser.previous.type).prefix
	if prefix_rule == nil {
		error("Expect expression.")
		return
	}

	can_assign := precedence <= .ASSIGNMENT
	prefix_rule(can_assign)

	for precedence <= rule_get(parser.current.type).precedence {
		parser_advance()
		infix_rule := rule_get(parser.previous.type).infix
		infix_rule(can_assign)
	}

	if can_assign && token_match(.EQUAL) {
		error("Invalid assignment target.")
	}
}

parse_variable :: proc(message: string) -> u8 {
	consume(.IDENTIFIER, message)
	declare_variable()
	if current.scope_depth > 0 do return 0
	return identifier_constant(&parser.previous)
}

identifier_constant :: proc(name: ^Token) -> u8 {
	return make_constant(allocate_string(name.text))
}

declare_variable :: proc() {
	if current.scope_depth == 0 do return
	name: ^Token = &parser.previous
	for i := (current.local_count - 1); i >= 0; i -= 1 {
		local := &current.locals[i]
		if local.depth != -1 && local.depth < current.scope_depth {
			break
		}

		if identifier_equals(name, &local.name) {
			error("Already a variable with this name in this scope.")
		}
	}
	add_local(name^)
}

identifier_equals :: proc(a, b: ^Token) -> bool {
	if a.length != b.length do return false
	return a.text == b.text
}

add_local :: proc(name: Token) {
	if current.local_count == U8_COUNT {
		error("Too many local variables in function.")
		return
	}

	local := &current.locals[current.local_count]
	current.local_count += 1
	local.name = name
	local.depth = -1
}

define_variable :: proc(global: u8) {
	if current.scope_depth > 0 {
		mark_initialized()
		return
	}
	emit_bytes(u8(Op.DEFINE_GLOBAL), global)
}

mark_initialized :: proc() {
	current.locals[current.local_count - 1].depth = current.scope_depth
}

rule_get :: proc(type: TokenType) -> ^ParseRule {
	return &rules[type]
}

consume :: proc(type: TokenType, message: string) {
	if parser.current.type == type {
		parser_advance()
		return
	}
	error_at_current(message)
}

non_consume :: proc(type: TokenType, message: string) {
	if parser.current.type == type {
		return
	}
	error_at_current(message)
}

current_chunk :: proc() -> ^Chunk {
	return compiling_chunk
}

emit_constant :: proc(value: Value) {
	write_constant(current_chunk(), value, u32(parser.previous.line))
}

emit_byte :: proc(byte: u8) {
	write_chunk(current_chunk(), u8(byte), u32(parser.previous.line))
}

emit_bytes :: proc(byte1, byte2: u8) {
	emit_byte(byte1)
	emit_byte(byte2)
}

end_compiler :: proc() {
	emit_return()
	when DEBUG_PRINT_CODE {
		if !parser.had_error {
			print_chunk(current_chunk(), "code")
		}
	}
}

emit_return :: proc() {
	emit_byte(u8(Op.RETURN))
}

error_at_current :: proc(message: string) {
	error_at(&parser.current, message)
}

error :: proc(message: string) {
	error_at(&parser.previous, message)
}

error_at :: proc(token: ^Token, message: string) {
	if parser.panic_mode do return
	parser.panic_mode = true
	fmt.eprintf("[line %v column %v] Error", token.line, token.start)

	if token.type == .EOF {
		fmt.print(" at end")
	} else if token.type == .ERROR {

	} else {
		fmt.eprintf(" at '{}'", token.text)
	}

	fmt.eprintf(": {}\n", message)
	parser.had_error = true
}
