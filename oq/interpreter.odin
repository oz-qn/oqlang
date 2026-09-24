package OQ

InterpretResult :: enum {
	OK,
	COMPILE_ERROR,
	RUNTIME_ERROR,
}

interpret :: proc(code: string) -> InterpretResult {
	chunk: Chunk

	if !compile(code, &chunk) {
		free_chunk(&chunk)
		return .COMPILE_ERROR
	}

	vm.chunk = &chunk
	vm.ip = 0

	result: InterpretResult = run()

	free_chunk(&chunk)
	return result
}
