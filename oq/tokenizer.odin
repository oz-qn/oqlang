package OQ

TokenType :: enum u8 {
	LEFT_PAREN,
	RIGHT_PAREN,
	LEFT_BRACE,
	RIGHT_BRACE,
	COMMA,
	DOT,
	MINUS,
	PLUS,
	SEMICOLON,
	SLASH,
	STAR,
	BANG,
	BANG_EQUAL,
	EQUAL,
	EQUAL_EQUAL,
	GREATER,
	GREATER_EQUAL,
	LESS,
	LESS_EQUAL,
	IDENTIFIER,
	STRING,
	NUMBER,
	AND,
	STRUCT,
	ELSE,
	FALSE,
	FOR,
	PROC,
	IF,
	NIL,
	OR,
	PRINT,
	RETURN,
	SUPER,
	THIS,
	TRUE,
	VAR,
	WHILE,
	ERROR,
	EOF,
}

Token :: struct {
	text:   string,
	start:  int,
	length: int,
	line:   int,
	type:   TokenType,
}

token_make :: #force_inline proc(type: TokenType) -> Token {
	return Token {
		type = type,
		start = scanner.start,
		length = scanner.current - scanner.start,
		line = scanner.line,
	}
}

token_error :: proc(message: string) -> Token {
	return Token{type = .ERROR, text = message, length = len(message), line = scanner.line}
}

token_number :: proc() -> Token {
	for is_digit(peek()) do advance()

	if peek() == '.' && is_digit(peek_next()) {
		advance()
		for is_digit(peek()) do advance()
	}

	return token_make(.NUMBER)
}

token_string :: proc() -> Token {
	for peek() != '"' && !is_at_end() {
		if peek() == '\n' do scanner.line += 1
		advance()
	}

	if is_at_end() do return token_error("Unterminated string.")

	advance()
	return token_make(.STRING)
}

identifier_type :: #force_inline proc() -> TokenType {
	text := scanner.code[scanner.start:scanner.current]
	switch text {
	case "and":
		return .AND
	case "struct":
		return .STRUCT
	case "else":
		return .ELSE
	case "false":
		return .FALSE
	case "true":
		return .TRUE
	case "for":
		return .FOR
	case "proc":
		return .PROC
	case "null":
		return .NIL
	case "if":
		return .IF
	case "or":
		return .OR
	case "print":
		return .PRINT
	case "return":
		return .RETURN
	case "super":
		return .SUPER
	case "this":
		return .THIS
	case "var":
		return .VAR
	case "while":
		return .WHILE
	}

	return .IDENTIFIER
}

token_identifier :: proc() -> Token {
	for is_alpha(peek()) || is_digit(peek()) do advance()
	return token_make(identifier_type())
}
