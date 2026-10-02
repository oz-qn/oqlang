package OQ

import "core:bufio"
import "core:fmt"
import "core:math"
import "core:os"
import "core:strings"

DEBUG :: false
DEBUG_PRINT_CODE :: false

VM :: struct {
	stack:   Stack,
	globals: Table,
	strings: Table,
	objects: ^Obj,
	chunk:   ^Chunk,
	ip:      int,
}

vm: VM

init_vm :: proc() {
	vm.stack.index = 1
	vm.objects = nil
	table_init(&vm.globals)
	table_init(&vm.strings)
}

free_vm :: proc() {
	free_objects()
	table_free(&vm.globals)
	table_free(&vm.strings)
}

read_byte :: #force_inline proc "contextless" () -> u8 {
	result := vm.chunk.code[vm.ip]
	vm.ip += 1
	return result
}

run :: proc() -> InterpretResult {
	for {
		instruction: Op = Op(read_byte())
		#partial switch instruction {
		case .RETURN:
			return InterpretResult.OK
		case .CONSTANT:
			constant: Value = read_constant()
			push(constant)
			break
		case .NEGATE:
			if !is_number(peep_stack(0)) {
				runtime_error("Operand must be a number.")
				return .RUNTIME_ERROR
			}
			push(-as_number(pop()))
		case .ADD:
			if is_string(peep_stack(0)) && is_string(peep_stack(1)) {
				concatenate()
			} else if !binary_op(instruction) {
				runtime_error("Operands must be a number or string.")
				return .RUNTIME_ERROR
			}
		case .SUB, .MUL, .DIV, .MOD, .GREATER, .GREATER_EQUAL, .LESS, .LESS_EQUAL, .POW:
			if !binary_op(instruction) {
				runtime_error("Operands must be a number.")
				return .RUNTIME_ERROR
			}
		case .EQUAL:
			push(values_equal(pop(), pop()))
		case .NOT_EQUAL:
			push(pop() != pop())
		case .NOT:
			push(is_falsey(pop()))
		case .NIL:
			push(nil)
		case .TRUE:
			push(true)
		case .FALSE:
			push(false)
		case .PRINT:
			print_value(pop())
			fmt.printf("\n")
		case .POP:
			pop()
		case .DEFINE_GLOBAL:
			name := read_string()
			table_insert(&vm.globals, name, peep_stack(0))
			pop()
		case .GET_GLOBAL:
			name := read_string()
			value, ok := table_get(&vm.globals, name)
			if !ok {
				runtime_error("Undefined variable '%s'.", name.str)
				return .RUNTIME_ERROR
			}
			push(value)
		case .SET_GLOBAL:
			name := read_string()
			if !table_set(&vm.globals, name, peep_stack(0)) {
				table_remove(&vm.globals, name)
				runtime_error("Undefined variable '%s'.", name.str)
				return .RUNTIME_ERROR
			}
		}
	}
}

binary_op :: #force_inline proc "contextless" (instruction: Op) -> bool {
	if !is_number(peep_stack(0)) || !is_number(peep_stack(1)) {
		return false
	}
	a := as_number(pop())
	b := as_number(pop())
	#partial switch instruction {
	case .ADD:
		push(b + a)
	case .SUB:
		push(b - a)
	case .DIV:
		push(b / a)
	case .MUL:
		push(b * a)
	case .MOD:
		push(math.mod(b, a))
	case .POW:
		push(math.pow(b, a))
	case .GREATER:
		push(b > a)
	case .LESS:
		push(b < a)
	case .LESS_EQUAL:
		push(b <= a)
	case .GREATER_EQUAL:
		push(b >= a)
	}
	return true
}

concatenate :: proc() {
	b := as_string(pop())
	a := as_string(pop())
	result := take_string(strings.concatenate([]string{a.str, b.str}))
	push(result)
}

runtime_error :: proc(format: string, args: ..any) {
	fmt.eprintfln(format, ..args)
	line := get_line(vm.chunk, u32(vm.ip))
	fmt.eprintfln("[line {}] in script", line)
	reset_stack()
}

repl :: proc() {
	scanner: bufio.Scanner
	stdin := os.to_stream(os.stdin)
	bufio.scanner_init(&scanner, stdin, context.temp_allocator)

	for {
		fmt.printf("> ")
		if !bufio.scanner_scan(&scanner) {
			break
		}
		line := bufio.scanner_text(&scanner)
		if line == "" do continue
		if line == "q" do break

		interpret(line)
	}

	if err := bufio.scanner_error(&scanner); err != nil {
		fmt.eprintln("error scanning input: %v", err)
	}

	free_all(context.temp_allocator)
}

load_file :: proc(filepath: string) -> string {
	full_path, path_err := os.get_absolute_path(filepath, context.temp_allocator)
	if path_err != nil {
		fmt.printfln("Error: {}. Couldn't get absolute path.", path_err)
		os.exit(0)
	}

	data, err := os.read_entire_file(filepath, context.temp_allocator)
	if err != nil {
		fmt.printfln("Error: {}. Data: {}. Error loading file. Exiting...", err, data)
		os.exit(0)
	}

	return string(data)
}

synchronize :: proc() {
	parser.panic_mode = false

	for parser.current.type != .EOF {
		if parser.previous.type == .SEMICOLON do return
		#partial switch parser.current.type {
		case .STRUCT, .PROC, .VAR, .FOR, .IF, .WHILE, .PRINT, .RETURN:
			return
		}
		parser_advance()
	}
}

read_string :: #force_inline proc "contextless" () -> ^ObjString {
	return as_string(read_constant())
}

run_vm :: proc() {
	init_vm()

	file_text: string

	args := os.args

	if len(args) == 1 {
		repl()
	} else if len(args) == 2 {
		path := args[1]
		file_text = load_file(path)
		result := interpret(file_text)
	} else {
		fmt.printfln("Usage: oqlang [filepath].")
		return
	}

	free_vm()
}
