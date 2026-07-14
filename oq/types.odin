package OQ

//Value :: union {
//	bool,
//	u32,
//	i32,
//	f32,
//	f64,
//}

Value :: f64

reinterpret_mem :: proc "contextless" (value: ^Value, $T: typeid) -> T {return (^T)(value)^}

reinterpret_memptr :: proc "contextless" (value: ^Value, $T: typeid) -> ^T {return (^T)(value)}

//is_bool :: #force_inline proc(value: Value) -> (bool, bool) {
//	b1, err := value.(bool)
//	return b1, err
//}
//
//is_i32 :: #force_inline proc(value: Value) -> (i32, bool) {
//	i1, err := value.(i32)
//	return i1, err
//}
