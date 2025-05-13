package tcp

import "core:c"

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

TcpConnectionInfo :: struct {
	state:       c.uint32_t,
	local_addr:  c.uint32_t,
	local_port:  c.uint16_t,
	remote_addr: c.uint32_t,
	remote_port: c.uint16_t,
	pid:         c.uint32_t,
}

TcpConnections :: struct {
	count:       c.uint32_t,
	connections: ^TcpConnectionInfo,
}

foreign import lib "../bin/krobe.a"
foreign lib {
	get_tcp_connections :: proc() -> ^TcpConnections ---
	free_tcp_connections :: proc(connections: ^TcpConnections) ---
}

get_tcp_state_string :: proc(state: c.uint32_t) -> string {
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
