package OQ

import "core:fmt"
import "core:strconv"

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

rules := [TokenType]ParseRule {
	.LEFT_PAREN    = {grouping, nil, .NONE},
	.RIGHT_PAREN   = {nil, nil, .NONE},
	.LEFT_BRACE    = {nil, nil, .NONE},
	.RIGHT_BRACE   = {nil, nil, .NONE},
	.COMMA         = {nil, nil, .NONE},
	.DOT           = {nil, nil, .NONE},
	.MINUS         = {unary, binary, .TERM},
	.PLUS          = {nil, binary, .TERM},
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
	.AND           = {nil, nil, .NONE},
	.STRUCT        = {nil, nil, .NONE},
	.ELSE          = {nil, nil, .NONE},
	.FALSE         = {literal, nil, .NONE},
	.FOR           = {nil, nil, .NONE},
	.PROC          = {nil, nil, .NONE},
	.IF            = {nil, nil, .NONE},
	.NIL           = {literal, nil, .NONE},
	.OR            = {nil, nil, .NONE},
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

compiling_chunk: ^Chunk

parser_advance :: proc() {
	parser.previous = parser.current

	for {
		parser.current = scan_token()
		if parser.current.type != .ERROR do break

		error_at_current(token_get_text(parser.current))
	}
}

compile :: proc(code: string, chunk: ^Chunk) -> bool {
	scanner_init(code)
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

variable :: proc(can_assign: bool) {
	named_variable(&parser.previous, can_assign)
}

named_variable :: proc(name: ^Token, can_assign: bool) {
	arg := identifier_constant(name)
	if can_assign && token_match(.EQUAL) {
		expression()
		emit_bytes(u8(Op.SET_GLOBAL), arg)
	} else {
		emit_bytes(u8(Op.GET_GLOBAL), arg)
	}
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
	} else {
		expression_statement()
	}
}

expression_statement :: proc() {
	expression()
	consume(.SEMICOLON, "Expect ';' after expression.")
	emit_byte(u8(Op.POP))
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
	return identifier_constant(&parser.previous)
}

identifier_constant :: proc(name: ^Token) -> u8 {
	return make_constant(allocate_string(name.text))
}

define_variable :: proc(global: u8) {
	emit_bytes(u8(Op.DEFINE_GLOBAL), global)
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
