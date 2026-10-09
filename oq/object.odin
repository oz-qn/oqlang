package OQ

import "core:fmt"
import "core:strings"

ObjType :: enum {
	Procedure,
	String,
}

Obj :: struct {
	next: ^Obj,
	type: ObjType,
}

ObjProcedure :: struct {
	using obj: Obj,
	chunk:     Chunk,
	name:      ^ObjString,
	arity:     int,
}

ObjString :: struct {
	using obj: Obj,
	str:       string,
}

free_objects :: proc() {
	obj := vm.objects
	for obj != nil {
		next := obj.next
		free_object(obj)
		obj = next
	}
}

free_object :: proc(obj: ^Obj) {
	switch obj.type {
	case .String:
		str := cast(^ObjString)obj
		delete(str.str)
		free(obj)
	case .Procedure:
		function := cast(^ObjProcedure)obj
		free_chunk(&function.chunk)
		free(obj)
	}
}

allocate_object :: #force_inline proc($T: typeid, obj_type: ObjType) -> ^Obj {
	object := cast(^Obj)new(T)
	object.type = obj_type
	object.next = vm.objects
	vm.objects = object
	return object
}

new_procedure :: proc() -> ^ObjProcedure {
	procedure: ^ObjProcedure = allocate_object_type(ObjProcedure, .Procedure)
	procedure.arity = 0
	procedure.name = nil
	chunk_init(&procedure.chunk)
	return procedure
}

copy_string :: #force_inline proc(str: string) -> ^ObjString {
	interned, ok := vm.strings[str]
	if ok {
		return as_string(interned)
	}
	strobj := allocate_object_type(ObjString, .String)
	strobj.str = strings.clone(str)
	table_insert(&vm.strings, strobj, strobj)
	return strobj
}

take_string :: #force_inline proc(str: string) -> ^ObjString {
	interned, ok := vm.strings[str]
	if ok {
		delete(str)
		return as_string(interned)
	}
	strobj := allocate_object_type(ObjString, .String)
	strobj.str = str
	table_insert(&vm.strings, strobj, strobj)
	return strobj
}

allocate_object_type :: #force_inline proc($T: typeid, type: ObjType) -> ^T {
	obj := new(T)
	obj.type = type
	obj.next = vm.objects
	vm.objects = obj
	return obj
}

print_object :: #force_inline proc(obj: ^Obj) {
	switch obj.type {
	case .String:
		fmt.printf(as_ostring(obj))
	case .Procedure:
		print_procedure(as_procedure(obj))
	}
}

print_procedure :: proc(procedure: ^ObjProcedure) {
	if procedure.name == nil {
		fmt.printf("<script>")
		return
	}
	fmt.printf("<proc %s>", procedure.name.str)
}

obj_equal :: #force_inline proc(a, b: ^Obj) -> bool {
	switch a.type {
	case .String:
		return a == b
	case .Procedure:
		return a == b
	}
	return false
}

is_obj_type :: #force_inline proc "contextless" (obj: ^Obj, type: ObjType) -> bool {
	return obj.type == type
}

is_obj_string :: #force_inline proc "contextless" (obj: ^Obj) -> bool {
	return obj.type == .String
}

is_obj_procedure :: #force_inline proc "contextless" (obj: ^Obj) -> bool {
	return obj.type == .Procedure
}

as_procedure :: #force_inline proc "contextless" (value: Value) -> ^ObjProcedure {
	return cast(^ObjProcedure)as_obj(value)
}

as_string :: #force_inline proc "contextless" (value: Value) -> ^ObjString {
	return cast(^ObjString)as_obj(value)
}

as_ostring :: #force_inline proc "contextless" (value: Value) -> string {
	return (cast(^ObjString)as_obj(value)).str
}
