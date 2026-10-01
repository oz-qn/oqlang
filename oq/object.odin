package OQ

import "core:fmt"
import "core:strings"

ObjType :: enum {
	String,
}

Obj :: struct {
	next: ^Obj,
	type: ObjType,
}

ObjString :: struct {
	using obj: Obj,
	str:       string,
	hash:      u32,
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
	}
}

allocate_object :: #force_inline proc($T: typeid, obj_type: ObjType) -> ^Obj {
	object := cast(^Obj)new(T)
	object.type = obj_type
	object.next = vm.objects
	vm.objects = object
	return object
}

allocate_string :: #force_inline proc(str: string) -> ^ObjString {
	interned, ok := vm.strings[str]
	if ok {
		return as_string(interned)
	}
	strobj := allocate_object_type(ObjString, .String)
	strobj.str = strings.clone(str)
	strobj.hash = string_hash(str)
	table_insert(&vm.strings, strobj, strobj)
	return strobj
}

string_hash :: proc(str: string) -> u32 {
	hash: u32 = 2166136261
	for char in str {
		hash ~= transmute(u32)char
		hash *= 16777619
	}
	return hash
}

take_string :: #force_inline proc(str: string) -> ^ObjString {
	interned, ok := vm.strings[str]
	if ok {
		return as_string(interned)
	}
	strobj := allocate_object_type(ObjString, .String)
	strobj.str = str
	strobj.hash = string_hash(str)
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
	}
}

obj_equal :: #force_inline proc(a, b: ^Obj) -> bool {
	switch a.type {
	case .String:
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

as_string :: #force_inline proc "contextless" (value: Value) -> ^ObjString {
	return cast(^ObjString)as_obj(value)
}

as_ostring :: #force_inline proc "contextless" (value: Value) -> string {
	return (cast(^ObjString)as_obj(value)).str
}
