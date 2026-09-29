package OQ

Value :: union {
	bool,
	f64,
}

is_falsey :: #force_inline proc "contextless" (value: Value) -> bool {
	return (value == nil) || (value == false) || (value == 0)
}

is_type :: #force_inline proc "contextless" (value: Value, $T: typeid) -> bool {
	_, ok := value.(T)
	return ok
}

is_number :: #force_inline proc "contextless" (value: Value) -> bool {
	_, ok := value.(f64)
	return ok
}

is_bool :: #force_inline proc "contextless" (value: Value) -> bool {
	_, ok := value.(bool)
	return ok
}

as_type :: #force_inline proc "contextless" (value: Value, $T: typeid) -> T {
	value, _ := value.(T)
	return value
}

as_number :: #force_inline proc "contextless" (value: Value) -> f64 {
	value, _ := value.(f64)
	return value
}

as_bool :: #force_inline proc "contextless" (value: Value) -> bool {
	value, _ := value.(bool)
	return value
}
