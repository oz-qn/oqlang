package OQ

import "core:fmt"
import "core:strconv"

ParseFn :: proc()

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
	.IDENTIFIER    = {nil, nil, .NONE},
	.STRING        = {nil, nil, .NONE},
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
	expression()
	consume(.EOF, "Expect end of expression.")
	end_compiler()
	return !parser.had_error
}

number :: proc() {
	value, ok := strconv.parse_f64(parser.previous.text)
	emit_constant(value)
}

literal :: proc() {
	#partial switch parser.previous.type {
	case .FALSE:
		emit_byte(.FALSE)
	case .TRUE:
		emit_byte(.TRUE)
	case .NIL:
		emit_byte(.NIL)
	}
}

unary :: proc() {
	operator_type := parser.previous.type

	parse_precedence(.UNARY)

	#partial switch operator_type {
	case .BANG:
		emit_byte(.NOT)
	case .MINUS:
		emit_byte(.NEGATE)
	case:
		return
	}
}

binary :: proc() {
	operator_type := parser.previous.type

	rule := rule_get(operator_type)
	parse_precedence(Precedence(int(rule.precedence) + 1))

	#partial switch operator_type {
	case .PLUS:
		emit_byte(.ADD)
	case .MINUS:
		emit_byte(.SUB)
	case .STAR:
		emit_byte(.MUL)
	case .SLASH:
		emit_byte(.DIV)
	case .PERCENT:
		emit_byte(.MOD)
	case .CARET:
		emit_byte(.POW)
	case .BANG_EQUAL:
		emit_byte(.NOT_EQUAL)
	case .EQUAL_EQUAL:
		emit_byte(.EQUAL)
	case .GREATER:
		emit_byte(.GREATER)
	case .GREATER_EQUAL:
		emit_byte(.GREATER_EQUAL)
	case .LESS:
		emit_byte(.LESS)
	case .LESS_EQUAL:
		emit_byte(.LESS_EQUAL)
	case:
		return
	}
}

grouping :: proc() {
	expression()
	consume(.RIGHT_PAREN, "Expect ')' after expression.")
}

expression :: proc() {
	parse_precedence(.ASSIGNMENT)
}

parse_precedence :: proc(precedence: Precedence) {
	parser_advance()
	prefix_rule := rule_get(parser.previous.type).prefix
	if prefix_rule == nil {
		error("Expect expression.")
		return
	}
	prefix_rule()

	for precedence <= rule_get(parser.current.type).precedence {
		parser_advance()
		infix_rule := rule_get(parser.previous.type).infix
		infix_rule()
	}
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

emit_byte :: proc(byte: Op) {
	write_chunk(current_chunk(), u8(byte), u32(parser.previous.line))
}

emit_bytes :: proc(byte1, byte2: Op) {
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
	emit_byte(.RETURN)
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
	fmt.eprintf("[line %v] Error", token.line)

	if token.type == .EOF {
		fmt.print(" at end")
	} else if token.type == .ERROR {

	} else {
		fmt.eprintf(" at '{}'", token.start)
	}

	fmt.eprintf(": {}\n", message)
	parser.had_error = true
}
