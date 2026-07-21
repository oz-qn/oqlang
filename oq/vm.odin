package OQ

import "core:fmt"
import "core:os"

DEBUG :: false

VM :: struct {
	chunk: ^Chunk,
	ip:    int,
	stack: Stack,
}

vm: VM

InterpretResult :: enum {
	OK,
	COMPILE_ERROR,
	RUNTIME_ERROR,
}

init_vm :: proc() {
	vm.stack.index = 1
}

free_vm :: proc() {

}

interpret :: proc(chunk: ^Chunk) -> InterpretResult {
	vm.chunk = chunk
	vm.ip = -1
	return run()
}

read_byte :: #force_inline proc() -> u8 {
	vm.ip += 1
	return vm.chunk.code[vm.ip]
}

run :: proc() -> InterpretResult {

	for {
		when DEBUG {
			//for i: u16 = 0; i < vm.stack.index; i += 1 {
			//	print_value(vm.stack.data[i])
			//	fmt.print("\n")
			//}
			disassemble_instruction(vm.chunk, vm.ip + 1)
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
			push(a + b)
			break
		case .SUB:
			a := pop()
			b := pop()
			push(a - b)
			break
		case .MUL:
			a := pop()
			b := pop()
			push(a * b)
			break
		case .DIV:
			a := pop()
			b := pop()
			push(a / b)
			break
		}
	}
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
	chunk: Chunk

	init_vm()

	file_text: string

	args := os.args
	if len(args) == 2 {
		path := args[1]
		file_text = load_file(path)
	} else {
		fmt.printfln("Usage: oqlang [filepath].")
		os.exit(0)
	}

	fmt.printfln("{}", file_text)

	write_constant(&chunk, 5.3, 0)
	write_constant(&chunk, 1.3, 0)
	write_chunk(&chunk, u8(Op.MUL), 0)
	write_chunk(&chunk, u8(Op.RETURN), 0)
	fmt.println("Interpreting following opcode chunk.")
	print_chunk(&chunk, "Main Chunk")
	result := interpret(&chunk)
	fmt.printf("INTERPRETER {}\n", result)
}
