package OQ

import "core:unicode/utf8"

Scanner :: struct {
	code:                 string,
	start, current, line: int,
	insert_semicolon:     bool,
}

scanner: Scanner

scanner_init :: proc(code: string) {
	scanner.code = code
	scanner.start = 0
	scanner.current = 0
	scanner.line = 1
}

scan_token :: proc() -> (token: Token) {
	skip_whitespace()
	scanner.start = scanner.current

	c: rune = utf8.RUNE_EOF if is_at_end() else advance()

	switch c {
	case utf8.RUNE_EOF:
		token = token_make(.SEMICOLON) if scanner.insert_semicolon else token_make(.EOF)
		scanner.insert_semicolon = false
	case '\n':
		scanner.insert_semicolon = false
		token = token_make(.NEWLINE)
	case '(':
		token = token_make(.LEFT_PAREN)
	case ')':
		token = token_make(.RIGHT_PAREN)
	case '{':
		token = token_make(.LEFT_BRACE)
	case '}':
		token = token_make(.RIGHT_BRACE)
	case ';':
		token = token_make(.SEMICOLON)
	case ',':
		token = token_make(.COMMA)
	case '.':
		token = token_make(.DOT)
	case '-':
		token = token_make(.MINUS_EQUALS if match('=') else .MINUS)
	case '+':
		token = token_make(.PLUS_EQUALS if match('=') else .PLUS)
	case '/':
		token = token_make(.SLASH_EQUALS if match('=') else .SLASH)
	case '*':
		token = token_make(.STAR_EQUALS if match('=') else .STAR)
	case '!':
		token = token_make(.BANG_EQUAL if match('=') else .BANG)
	case '=':
		token = token_make(.EQUAL_EQUAL if match('=') else .EQUAL)
	case '<':
		token = token_make(.LESS_EQUAL if match('=') else .LESS)
	case '>':
		token = token_make(.GREATER_EQUAL if match('=') else .GREATER)
	case ':':
		token = token_make(.COLON_EQUALS if match('=') else .COLON)
	case '%':
		token = token_make(.PERCENT)
	case '^':
		token = token_make(.CARET)
	case '"':
		token = token_string()
	case:
		if is_alpha(c) {
			token = token_identifier()
			break
		}
		if is_digit(c) {
			token = token_number()
			break
		}
		token = token_error("Unexpected character.")
	}

	#partial switch token.type {
	case .IDENTIFIER, .NUMBER, .STRING, .NIL, .CARET, .FALSE, .TRUE, .EOF, .RIGHT_PAREN:
		scanner.insert_semicolon = true
	case:
		scanner.insert_semicolon = false
	}

	return
}

skip_whitespace :: proc() {
	for !is_at_end() {
		c := peek()
		switch c {
		case ' ', '\r', '\t':
			advance()
			break
		case '\n':
			if scanner.insert_semicolon {
				return
			}
			scanner.line += 1
			advance()
			break
		case '/':
			if peek_next() == '/' {
				for (peek() != '\n') && !is_at_end() {
					advance()
				}
			} else {
				return
			}
		case utf8.RUNE_EOF:
			return
		case:
			return
		}
	}
}

is_alpha :: proc(c: rune) -> bool {
	return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_'
}

is_digit :: proc(c: rune) -> bool {
	return c >= '0' && c <= '9'
}

peek :: #force_inline proc() -> rune {
	if is_at_end() do return utf8.RUNE_EOF
	return rune(scanner.code[scanner.current])
}

peek_next :: #force_inline proc() -> rune {
	if is_at_end() do return utf8.RUNE_EOF
	return rune(scanner.code[scanner.current + 1])
}

match :: proc(expected: rune) -> bool {
	if is_at_end() do return false
	if rune(scanner.code[scanner.current]) != expected do return false
	scanner.current += 1
	return true
}

advance :: proc() -> rune {
	scanner.current += 1
	return rune(scanner.code[scanner.current - 1])
}

is_at_end :: #force_inline proc() -> bool {
	return scanner.current >= len(scanner.code)
}
