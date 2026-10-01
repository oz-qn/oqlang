package OQ

Table :: map[string]Value

table_init :: #force_inline proc(table: ^Table) {
	table^ = make(Table)
}

table_insert :: #force_inline proc "contextless" (table: ^Table, key: ^ObjString, value: Value) {
	table[key.str] = value
}

table_remove :: #force_inline proc(table: ^Table, key: ^ObjString) -> bool {
	if !(key.str in table) do return false
	k, v := delete_key(table, key.str)
	return v == nil
}

table_get :: #force_inline proc "contextless" (table: ^Table, key: ^ObjString) -> (Value, bool) {
	return table[key.str]
}

table_clear :: #force_inline proc "contextless" (table: ^Table) {
	clear(table)
}

table_free :: #force_inline proc(table: ^Table) {
	delete(table^)
}

table_find_string :: #force_inline proc "contextless" (
	table: ^Table,
	key: string,
) -> (
	^ObjString,
	bool,
) {
	value, ok := table[key]
	if ok do return as_string(value), true
	return nil, false
}
