package main

import "core:c"
import "core:fmt"
import "core:log"
import "core:os"
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

main :: proc() {
	defer free_all(context.allocator)

	l := log.create_console_logger()
	context.logger = l

	connections := tcp.get_tcp_connections()
	defer tcp.free_tcp_connections(connections)
	if connections == nil {
		log.error("Failed to get TCP connections!")
		os.exit(69)
	}

	conn_slice := slice.from_ptr(connections.connections, int(connections.count))

	for conn in conn_slice {
		if conn.pid == 4 {continue} // system process, skip it for now even tho many sevices run under it
		if conn.state == tcp.TCP_STATE_LISTEN || conn.state == tcp.TCP_STATE_ESTAB {
			r := tcp.get_proc_info(conn.pid)
			if r == nil {
				continue
			}
			fmt.printf("port: %#v, pid: %#v (handle: %#v), path: %#v\n", conn.local_port, conn.pid, tcp.get_hwnd(conn.pid), r)
		}
	}
}
