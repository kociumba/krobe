package tcp

import "core:fmt"
import "core:log"
import "core:slice"
import "core:strings"
import win "core:sys/windows"

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

foreign import "system:iphlpapi.lib"
foreign import "system:ws2_32.lib"
foreign import "system:user32.lib"
foreign import lib "../bin/krobe.lib"
foreign lib {
	get_tcp_connections :: proc() -> ^TcpConnections ---
	free_tcp_connections :: proc(connections: ^TcpConnections) ---
	print_tcp_connections :: proc(connections: ^TcpConnections) ---
	get_hwnd :: proc(process_id: win.DWORD) -> win.HWND ---
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