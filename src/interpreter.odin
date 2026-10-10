package OQ

InterpretResult :: enum {
	OK,
	COMPILE_ERROR,
	RUNTIME_ERROR,
}

interpret :: proc(code: string) -> InterpretResult {
	procedure := compile(code)
	if procedure == nil do return .COMPILE_ERROR

	push(as_obj(procedure))
	vm_call(procedure, 0)
	return run()
}
