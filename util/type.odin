package util

import "core:fmt"
get_type :: #force_inline proc(value: $T) -> typeid {
	return typeid_of(type_of(value))
}

print_type :: #force_inline proc(value: $T) {
	fmt.printf("type of value {} is {}\n", value, typeid_of(type_of(value)))
}
