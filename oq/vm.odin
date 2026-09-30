package OQ

import "core:bufio"
import "core:fmt"
import "core:math"
import "core:os"

DEBUG :: false
DEBUG_PRINT_CODE :: false

VM :: struct {
	chunk: ^Chunk,
	stack: Stack,
	ip:    int,
}

vm: VM

init_vm :: proc() {
	vm.stack.index = 1
}

free_vm :: proc() {

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
			print_value(pop())
			fmt.print("\n")
			return InterpretResult.OK
		case .CONSTANT:
			constant: Value = read_constant(read_byte())
			push(constant)
			break
		case .NEGATE:
			if !is_number(peep_stack(0)) {
				runtime_error("Operand must be a number.")
				return .RUNTIME_ERROR
			}
			push(-as_number(pop()))
		case .ADD, .SUB, .MUL, .DIV, .MOD, .GREATER, .GREATER_EQUAL, .LESS, .LESS_EQUAL, .POW:
			if !binary_op(instruction) {
				runtime_error("Operands must be a number,")
				return .RUNTIME_ERROR
			}
		case .EQUAL:
			push(pop() == pop())
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
}
