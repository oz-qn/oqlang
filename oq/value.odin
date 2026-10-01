package OQ

Value :: union {
	bool,
	f64,
	^Obj,
}

values_equal :: #force_inline proc(a, b: Value) -> bool {
	switch type in a {
	case f64, bool:
		return a == b
	case ^Obj:
		if !is_obj(b) do return false
		if type.type != as_obj(b).type do return false
		return obj_equal(type, as_obj(b))
	}
	return false
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

is_obj :: #force_inline proc "contextless" (value: Value) -> bool {
	_, ok := value.(^Obj)
	return ok
}

is_string :: #force_inline proc "contextless" (value: Value) -> bool {
	result, ok := value.(^Obj)
	return result.type == .String if ok else false
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

as_obj :: #force_inline proc "contextless" (value: Value) -> ^Obj {
	value, _ := value.(^Obj)
	return value
}
