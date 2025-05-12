package main

import "core:c"
import "core:encoding/json"
import "core:fmt"
import "core:log"
import "core:os"
import "core:path/filepath"
import "core:slice"
import "core:testing"
import "core:flags"
import "tcp"
import "udp"

// Common interface for both TCP and UDP connection types
Connection_Info :: struct {
	local_addr:  u32,
	local_port:  u32,
	remote_addr: u32,
	remote_port: u32,
	pid:         u32,
	state:       u32, // Optional for UDP (always 0)
}

Connections :: struct {
	count:       u32,
	connections: []Connection_Info,
}

get_connections :: proc(use_udp: bool) -> (result: Connections) {
	if use_udp {
		udp_endpoints := udp.get_udp_endpoints()
		if udp_endpoints == nil {
			return {}
		}
		defer udp.free_udp_endpoints(udp_endpoints)

		// Convert UDP endpoints to our common format
		result.count = udp_endpoints.count
		result.connections = make([]Connection_Info, int(udp_endpoints.count))

		udp_slice := slice.from_ptr(udp_endpoints.endpoints, int(udp_endpoints.count))
		for i := 0; i < int(udp_endpoints.count); i += 1 {
			result.connections[i] = {
				local_addr  = udp_slice[i].local_addr,
				local_port  = udp_slice[i].local_port,
				remote_addr = udp_slice[i].remote_addr,
				remote_port = udp_slice[i].remote_port,
				pid         = udp_slice[i].pid,
				state       = 0, // UDP doesn't have states
			}
		}
	} else {
		tcp_connections := tcp.get_tcp_connections()
		if tcp_connections == nil {
			return {}
		}
		defer tcp.free_tcp_connections(tcp_connections)

		// Convert TCP connections to our common format
		result.count = tcp_connections.count
		result.connections = make([]Connection_Info, int(tcp_connections.count))

		tcp_slice := slice.from_ptr(tcp_connections.connections, int(tcp_connections.count))
		for i := 0; i < int(tcp_connections.count); i += 1 {
			result.connections[i] = {
				local_addr  = tcp_slice[i].local_addr,
				local_port  = u32(tcp_slice[i].local_port),
				remote_addr = tcp_slice[i].remote_addr,
				remote_port = u32(tcp_slice[i].remote_port),
				pid         = tcp_slice[i].pid,
				state       = tcp_slice[i].state,
			}
		}
	}

	return result
}

// options paresed from cli args
Options :: struct {
    use_udp: bool `args:"name=udp" usage:"if true, searches udp connections instead of tcp"`,
    use_full: bool `args:"name=full" usage:"if true, includes full absolute paths to found executables"`,
    use_json: bool `args:"name=json" usage:"if true, outputs the data in a json format, for piping into other programs"`
}

opts: Options

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

// the struct outputed in an array when -json is set
json_out :: struct {
	port:  int,
	pid:   int,
	title: Maybe(string),
	path:  string,
}

main :: proc() {
	defer free_all(context.allocator)

    style: flags.Parsing_Style = .Odin
    flags.parse_or_exit(&opts, os.args, style)

	l := log.create_console_logger(log.Level.Info)
	// disable logging when json output is enabled for an uninterrupted json stream
	if opts.use_json {
		l = log.create_console_logger(log.Level.Fatal)
	}
	context.logger = l

	connections := get_connections(opts.use_udp)

	if len(connections.connections) == 0 {
		protocol := opts.use_udp ? "UDP" : "TCP"
		log.errorf("Failed to get %s connections!", protocol)
		os.exit(69)
	}

	json_struct := make([dynamic]json_out)
	defer delete(json_struct)

	for conn in connections.connections {
		if conn.pid == 4 {continue} 	// system process, skip it for now even tho many sevices run under it

		should_include :=
			opts.use_udp ||
			(!opts.use_udp && (conn.state == tcp.TCP_STATE_LISTEN || conn.state == tcp.TCP_STATE_ESTAB))

		if should_include {
			r := tcp.get_proc_info(conn.pid)
			if r == nil {
				continue
			}
			if !opts.use_full {
				r = filepath.base(r.?)
			}
			if opts.use_json {
				append(
					&json_struct,
					json_out {
						port = int(conn.local_port),
						pid = int(conn.pid),
						title = tcp.get_window_title(tcp.get_hwnd(conn.pid)),
						path = r.?,
					},
				)
			} else {
				fmt.printf(
					"port: %#v, pid: %#v (title: %#v), path: %#v\n",
					conn.local_port,
					conn.pid,
					tcp.get_window_title(tcp.get_hwnd(conn.pid)).? or_else "[no window]",
					r,
				)
			}
		}
	}

	if opts.use_json {
		data, err := json.marshal(json_struct, {pretty = true})
		defer delete(data)
		if err != nil {
			log.error(err)
		}
		fmt.printf("%s", data)
	}
}
