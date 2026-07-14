package OQ

import "core:fmt"

LineData :: struct {
	pc:         u32,
	line_delta: u16,
}

current_line: u16 = 0
current_pc: u32 = 0

Chunk :: struct {
	code:      [dynamic]u8,
	constants: [dynamic]Value,
	line_data: [dynamic]LineData,
}

clear_chunk :: proc(chunk: ^Chunk) {
	clear(&chunk.code)
	shrink_dynamic_array(&chunk.code)
}

clear_value_array :: proc(array: ^[dynamic]Value) {
	clear(array)
	shrink_dynamic_array(array)
}

write_constant :: proc(chunk: ^Chunk, value: Value, line: u16) {
	index := add_constant(chunk, value)
	if (index < 256) {
		write_chunk(chunk, u8(Op.CONSTANT), line)
		write_chunk(chunk, u8(index), line)
	} else {
		write_chunk(chunk, u8(Op.CONSTANT_LONG), line)
		write_chunk(chunk, u8(index & 0xff), line)
		write_chunk(chunk, u8((index >> 8) & 0xff), line)
		write_chunk(chunk, u8((index >> 16) & 0xff), line)
	}
}

write_chunk :: proc(chunk: ^Chunk, data: u8, line: u16) {
	append_elem(&chunk.code, data)
	if line != current_line {
		append_elem(&chunk.line_data, LineData{current_pc, line - current_line})
		current_line = line
	}
	current_pc += 1
}

get_line :: proc(chunk: ^Chunk, op: u32) -> u16 {
	final: u16
	for value, index in chunk.line_data {
		final += value.line_delta
		if value.pc >= op {
			return final
		}
	}
	return 0
}

print_chunk :: proc(chunk: ^Chunk, name: string = "chunk") {
	fmt.printf("=== {} ===\n", name)

	for i := 0; i < len(&chunk.code); i += 1 {
		i = disassemble_instruction(chunk, i)
	}
}

add_constant :: proc(chunk: ^Chunk, value: Value) -> int {
	append_elem(&chunk.constants, value)
	return len(&chunk.constants) - 1
}

read_constant :: #force_inline proc(instruction: u8) -> Value {
	return vm.chunk.constants[instruction]
}

disassemble_instruction :: proc(chunk: ^Chunk, index: int) -> int {
	fmt.printf("%0*d ", 4, index)

	instruction: u8 = chunk.code[index]
	#partial switch Op(instruction) {
	case Op.RETURN:
		return simple_instruction("OP_RETURN", index)
	case Op.CONSTANT:
		return constant_instruction("OP_CONSTANT", chunk, index)
	case Op.CONSTANT_LONG:
		return constant_long_instruction("OP_CONSTANT_LONG", chunk, index)
	case Op.ADD:
		return simple_instruction("OP_ADD", index)
	case Op.SUB:
		return simple_instruction("OP_SUB", index)
	case Op.DIV:
		return simple_instruction("OP_DIV", index)
	case Op.MUL:
		return simple_instruction("OP_MUL", index)
	case:
		fmt.printf("unknown opcode {}\n", Op(instruction))
		return index + 1
	}

	return index
}

print_value :: proc(value: Value) {
	fmt.printf("{}", value)
}


simple_instruction :: #force_inline proc(name: string, index: int) -> int {
	fmt.printf("{}\n", name)
	return index + 1
}

constant_instruction :: #force_inline proc(name: string, chunk: ^Chunk, index: int) -> int {
	constant := chunk.code[index + 1]
	fmt.printf("{} {} '", name, constant)
	print_value(chunk.constants[constant])
	fmt.print("'\n")
	return index + 1
}

constant_long_instruction :: #force_inline proc(name: string, chunk: ^Chunk, index: int) -> int {
	constant :=
		(chunk.code[index + 1] | (chunk.code[index + 2] << 8) | (chunk.code[index + 3] << 16))
	fmt.printf("{} {} '", name, constant)
	print_value(chunk.constants[constant])
	fmt.print("'\n")
	return index + 3
}
