package OQ

import "core:fmt"

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

		instruction: u8 = read_byte()
		#partial switch Op(instruction) {
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

run_vm :: proc() {
	chunk: Chunk
	init_vm()
	write_constant(&chunk, 5.3, 0)
	write_constant(&chunk, 2.0, 0)
	write_chunk(&chunk, u8(Op.MUL), 0)
	write_chunk(&chunk, u8(Op.RETURN), 0)
	fmt.println("Interpreting following opcode chunk.")
	print_chunk(&chunk, "Main Chunk")
	result := interpret(&chunk)
	fmt.printf("INTERPRETER {}\n", result)
}
