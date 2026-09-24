package OQ

import "core:fmt"
import "core:unicode/utf8"

Scanner :: struct {
	code:                 string,
	start, current, line: int,
}

scanner: Scanner

scanner_init :: proc(code: string) {
	scanner.code = code
	scanner.start = 0
	scanner.current = 0
	scanner.line = 1
}

scan_token :: proc() -> Token {
	skip_whitespace()
	scanner.start = scanner.current

	if is_at_end() {
		return token_make(.EOF)
	}

	c: rune = advance()
	if is_alpha(c) do return token_identifier()
	if is_digit(c) do return token_number()

	switch c {
	case '(':
		return token_make(.LEFT_PAREN)
	case ')':
		return token_make(.RIGHT_PAREN)
	case '{':
		return token_make(.LEFT_BRACE)
	case '}':
		return token_make(.RIGHT_BRACE)
	case ';':
		return token_make(.SEMICOLON)
	case ',':
		return token_make(.COMMA)
	case '.':
		return token_make(.DOT)
	case '-':
		return token_make(.MINUS)
	case '+':
		return token_make(.PLUS)
	case '/':
		return token_make(.SLASH)
	case '*':
		return token_make(.STAR)
	case '!':
		return token_make(.BANG_EQUAL if match('=') else .BANG)
	case '=':
		return token_make(.EQUAL_EQUAL if match('=') else .EQUAL)
	case '<':
		return token_make(.LESS_EQUAL if match('=') else .LESS)
	case '>':
		return token_make(.GREATER_EQUAL if match('=') else .GREATER)
	case ':':
		return token_make(.COLONCOLON if match(':') else .COLON)
	case '"':
		return token_string()
	}

	return token_error("Unexpected character.")
}

skip_whitespace :: proc() {
	for !is_at_end() {
		c := peek()
		switch c {
		case ' ', '\r', '\t':
			advance()
			break
		case '\n':
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

is_at_end :: proc() -> bool {
	return scanner.current >= (len(scanner.code) - 1)
}
