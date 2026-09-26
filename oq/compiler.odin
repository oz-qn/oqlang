package OQ

import "core:fmt"

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

parser: Parser

parser_advance :: proc() {
	parser.previous = parser.current

	for {
		parser.current = scan_token()
		fmt.println(parser.current.type)
		if parser.current.type != .ERROR do break

		error_at_current(token_get_text(parser.current))
	}
}

compile :: proc(code: string, chunk: ^Chunk) -> bool {
	scanner_init(code)
	for {
		token := scan_token()
		fmt.println(token)
		if token.type == .EOF do break
	}
	// parser_advance()
	// consume(.EOF, "Expect end of expression.")
	return !parser.had_error
}

consume :: proc(type: TokenType, message: string) {
	if parser.current.type == type {
		parser_advance()
		return
	}
	error_at_current(message)
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
