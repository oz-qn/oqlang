package main

import "core:fmt"
import "core:mem"
import "oq"

DEBUG :: true

main :: proc() {
	when DEBUG {
		tracker: mem.Tracking_Allocator
		mem.tracking_allocator_init(&tracker, context.allocator)
		context.allocator = mem.tracking_allocator(&tracker)

		defer {
			if len(tracker.allocation_map) > 0 {
				fmt.eprintf("=== %v memory leaks found: ===\n", len(tracker.allocation_map))
				for _, entry in tracker.allocation_map {
					fmt.eprintf("-> %v bytes @ %v\n", entry.size, entry.location)
				}
			} else {
				fmt.print("=== No leaks found. ===\n")
			}
			if len(tracker.bad_free_array) > 0 {
				fmt.eprintf("=== %v incorrect frees: ===\n", len(tracker.bad_free_array))
				for entry in tracker.bad_free_array {
					fmt.eprintf("-> %p @ %v\n", entry.memory, entry.location)
				}
			} else {
				fmt.print("=== No bad array free's found. ===\n")
			}
			mem.tracking_allocator_destroy(&tracker)
		}
	}

	oq.run_vm()
}
