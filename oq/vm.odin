package OQ

import "core:bufio"
import "core:fmt"
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

read_byte :: #force_inline proc() -> u8 {
	result := vm.chunk.code[vm.ip]
	vm.ip += 1
	return result
}

run :: proc() -> InterpretResult {
	for {
		when DEBUG {
			//for i: u16 = 0; i < vm.stack.index; i += 1 {
			//	print_value(vm.stack.data[i])
			//	fmt.print("\n")
			//}
			// disassemble_instruction(vm.chunk, vm.ip + 1)
		}

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
			push(-pop())
		case .ADD:
			a := pop()
			b := pop()
			push(b + a)
			break
		case .SUB:
			a := pop()
			b := pop()
			push(b - a)
			break
		case .MUL:
			a := pop()
			b := pop()
			push(b * a)
			break
		case .DIV:
			a := pop()
			b := pop()
			push(b / a)
			break
		}
	}
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
