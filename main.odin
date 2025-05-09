package main

import "core:c"
import "core:fmt"
import "core:log"
import "core:slice"
import win "core:sys/windows"
import "core:testing"

TcpConnectionInfo :: struct {
	state:       win.DWORD, // TCP connection state
	local_addr:  win.DWORD, // Local address in network byte order
	local_port:  win.WORD, // Local port in host byte order
	remote_addr: win.DWORD, // Remote address in network byte order
	remote_port: win.WORD, // Remote port in host byte order
	pid:         win.DWORD, // Process ID
}

TcpConnections :: struct {
	count:       win.DWORD, // Number of connections
	connections: ^TcpConnectionInfo, // Array of connections
}

TCP_STATE_CLOSED :: 1
TCP_STATE_LISTEN :: 2
TCP_STATE_SYN_SENT :: 3
TCP_STATE_SYN_RCVD :: 4
TCP_STATE_ESTAB :: 5
TCP_STATE_FIN_WAIT1 :: 6
TCP_STATE_FIN_WAIT2 :: 7
TCP_STATE_CLOSE_WAIT :: 8
TCP_STATE_CLOSING :: 9
TCP_STATE_LAST_ACK :: 10
TCP_STATE_TIME_WAIT :: 11
TCP_STATE_DELETE_TCB :: 12

foreign import "system:iphlpapi.dll"
foreign import "system:ws2_32.dll"
foreign import lib "bin/krobe.lib"
foreign lib {
	get_tcp_connections :: proc() -> ^TcpConnections ---
	free_tcp_connections :: proc(connections: ^TcpConnections) ---
	print_tcp_connections :: proc(connections: ^TcpConnections) ---
}

get_tcp_state_string :: proc(state: win.DWORD) -> string {
	switch state {
	case TCP_STATE_CLOSED:
		return "CLOSED"
	case TCP_STATE_LISTEN:
		return "LISTEN"
	case TCP_STATE_SYN_SENT:
		return "SYN_SENT"
	case TCP_STATE_SYN_RCVD:
		return "SYN_RCVD"
	case TCP_STATE_ESTAB:
		return "ESTABLISHED"
	case TCP_STATE_FIN_WAIT1:
		return "FIN_WAIT1"
	case TCP_STATE_FIN_WAIT2:
		return "FIN_WAIT2"
	case TCP_STATE_CLOSE_WAIT:
		return "CLOSE_WAIT"
	case TCP_STATE_CLOSING:
		return "CLOSING"
	case TCP_STATE_LAST_ACK:
		return "LAST_ACK"
	case TCP_STATE_TIME_WAIT:
		return "TIME_WAIT"
	case TCP_STATE_DELETE_TCB:
		return "DELETE_TCB"
	case:
		return "UNKNOWN"
	}
}

ipv4_to_string :: proc(addr: win.DWORD) -> string {
	bytes := [4]byte {
		byte((addr) & 0xFF),
		byte((addr >> 8) & 0xFF),
		byte((addr >> 16) & 0xFF),
		byte((addr >> 24) & 0xFF),
	}

	return fmt.aprintf("%d.%d.%d.%d", bytes[0], bytes[1], bytes[2], bytes[3])
}

@test
main_test :: proc(t: ^testing.T) {
    defer free_all(context.allocator)

	connections := get_tcp_connections()
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

	free_tcp_connections(connections)
}

main :: proc() {
    log.info("gabagool")
}
