package main

import "core:c"
import "core:encoding/json"
import "core:fmt"
import "core:log"
import "core:os"
import "core:path/filepath"
import "core:slice"
import "core:testing"
import "tcp"

@(test)
main_test :: proc(t: ^testing.T) {
	defer free_all(context.allocator)

	connections := tcp.get_tcp_connections()
	if connections == nil {
		log.error("Failed to get TCP connections!")
		return
	}

	log.info(connections)

	// fmt.printf("Total TCP connections: %d\n", connections.count)
	// fmt.println("------------------------------------------------------")
	// fmt.println("  Local Address:Port    Remote Address:Port    State    PID")
	// fmt.println("------------------------------------------------------")

	// conn_slice := slice.from_ptr(connections.connections, int(connections.count))
	// for conn in conn_slice {
	// 	local_ip := ipv4_to_string(conn.local_addr)
	// 	remote_ip := ipv4_to_string(conn.remote_addr)

	// 	fmt.printf(
	// 		"%15s:%-5d %15s:%-5d %12s %5d\n",
	// 		local_ip,
	// 		conn.local_port,
	// 		remote_ip,
	// 		conn.remote_port,
	// 		get_tcp_state_string(conn.state),
	// 		conn.pid,
	// 	)
	// }

	tcp.free_tcp_connections(connections)
}

// basic flag detection, should ideally use the core:flags package but this will do for now
has_flag :: proc(flag: string) -> bool {
	if slice.contains(os.args, flag) {
		return true
	}
	return false
}

// the struct outputed in an array when -json is set
json_out :: struct {
	port:   int,
	pid:    int,
	handle: int,
	path:   string,
}

main :: proc() {
	defer free_all(context.allocator)

    // disable logging when json output is enabled for an uninterrupted json stream
	if !has_flag("-json") {
		l := log.create_console_logger()
		context.logger = l
	}

	connections := tcp.get_tcp_connections()
	defer tcp.free_tcp_connections(connections)
	if connections == nil {
		log.error("Failed to get TCP connections!")
		os.exit(69)
	}

	conn_slice := slice.from_ptr(connections.connections, int(connections.count))

	json_struct := make([dynamic]json_out)
	defer delete(json_struct)

	for conn in conn_slice {
		if conn.pid == 4 {continue} // system process, skip it for now even tho many sevices run under it
		if conn.state == tcp.TCP_STATE_LISTEN || conn.state == tcp.TCP_STATE_ESTAB {
			r := tcp.get_proc_info(conn.pid)
			if r == nil {
				continue
			}
			if !has_flag("-full") {
				r = filepath.base(r.?)
			}
			if has_flag("-json") {
				append(
					&json_struct,
					json_out {
						port = int(conn.local_port),
						pid = int(conn.pid),
						handle = int(uintptr(tcp.get_hwnd(conn.pid))),
						path = r.?,
					},
				)
			} else {
				fmt.printf(
					"port: %#v, pid: %#v (handle: %#v), path: %#v\n",
					conn.local_port,
					conn.pid,
					uintptr(tcp.get_hwnd(conn.pid)),
					r,
				)
			}
		}
	}

	if has_flag("-json") {
		data, err := json.marshal(json_struct, {pretty = true})
		defer delete(data)
		if err != nil {
			log.error(err)
		}
		fmt.printf("%s", data)
	}
}
