package main

import "core:fmt"
import "oq"

main :: proc() {
	buffer: [2048]u8


	oq.push_bits(&buffer, i32(12345))
	my_value := oq.pop_bits(&buffer, i32)
	fmt.printf("type: {} data: {}", typeid_of(type_of(my_value)), my_value)
	//oq.run_vm()
}
