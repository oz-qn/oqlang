package OQ

import "base:intrinsics"

add_op :: #force_inline proc(a, b: $T) -> T where intrinsics.type_is_numeric(T) {
	return a + b
}

sub_op :: #force_inline proc(a, b: $T) -> T where intrinsics.type_is_numeric(T) {
	return a - b
}

mul_op :: #force_inline proc(a, b: $T) -> T where intrinsics.type_is_numeric(T) {
	return a * b
}

div_op :: #force_inline proc(a, b: $T) -> T where intrinsics.type_is_numeric(T) {
	return a / b
}

neg_op :: #force_inline proc(a: $T) -> T where intrinsics.type_is_numeric(T) {
	return -a
}
