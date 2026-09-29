package OQ

import "base:intrinsics"
import "base:runtime"
import "core:mem"

STACK_MAX :: 256

Stack :: struct {
	data:  [STACK_MAX]Value,
	index: u16,
}

push_bits :: proc(stack: ^[2048]u8, value: any) {
	index := 0
	copy(stack[index:], mem.any_to_bytes(value))
}

pop_bits :: proc(stack: ^[2048]u8, $T: typeid) -> T {
	size := size_of(T)
	start := 0
	value: T
	intrinsics.mem_copy(&value, raw_data(stack[start:start + size]), size)
	return value
}

push :: #force_inline proc "contextless" (value: Value) {
	vm.stack.data[vm.stack.index] = value
	vm.stack.index += 1
}

pop :: #force_inline proc "contextless" () -> Value {
	vm.stack.index -= 1
	return vm.stack.data[vm.stack.index]
}

peep_stack :: #force_inline proc "contextless" (distance: int) -> Value {
	return vm.stack.data[vm.stack.index - 1]
}

reset_stack :: #force_inline proc "contextless" () {
	vm.stack.index = 1
}
