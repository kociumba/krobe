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
foreign import kernel32 "system:kernel32.lib"
foreign kernel32 {
	// imported here since sys/windows, doesn't seem to import it
	QueryFullProcessImageNameW :: proc(hProcess: win.HANDLE, dwFlags: win.DWORD, lpExeName: win.LPWSTR, lpdwSize: win.PDWORD) -> win.BOOL ---
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

// decodes the u32 encoded ipv4 adress to a readable ip string
ipv4_to_string :: proc(addr: win.DWORD) -> string {
	bytes := [4]byte {
		byte((addr) & 0xFF),
		byte((addr >> 8) & 0xFF),
		byte((addr >> 16) & 0xFF),
		byte((addr >> 24) & 0xFF),
	}

	return fmt.aprintf("%d.%d.%d.%d", bytes[0], bytes[1], bytes[2], bytes[3])
}

// placeholder string return, might return a struct or something else later
get_proc_info :: proc(pid: win.DWORD) -> Maybe(string) {
	h_process := win.OpenProcess(win.PROCESS_QUERY_INFORMATION, false, pid)
	if h_process == nil {
		if win.GetLastError() == win.ERROR_ACCESS_DENIED {
			// children := get_child_pids(pid)
			// defer delete(children)

			// if len(children) > 0 {
			// 	log.infof("Found %d children for PID %d", len(children), pid)
			// 	for child_pid in children {
			// 		log.infof("Attempting child PID %d", child_pid)
			// 		child_info := get_proc_info(child_pid)
			// 		if child_info != nil {
			// 			return fmt.tprintf("Parent of: %s", child_info.?)
			// 		}
			// 	}
			// }
		}
		log.errorf(
			"OpenProcess failed for PID %d: %s",
			pid,
			get_win32_error_message(win.GetLastError()),
		)
		return nil
	}
	defer win.CloseHandle(h_process)

	process_path: [win.MAX_PATH]u16
	buffer_size := win.DWORD(win.MAX_PATH)

	if QueryFullProcessImageNameW(h_process, 0, slice.as_ptr(process_path[:]), &buffer_size) ==
	   win.FALSE {
		log.errorf(
			"QueryFullProcessImageName failed for PID %d: %s",
			pid,
			get_win32_error_message(win.GetLastError()),
		)
		return nil
	}

	r, err := win.utf16_to_utf8(process_path[:buffer_size])
	if err != nil {
		log.error("could not convert to utf8")
	}
	return string(r)
}

// shortcut utility to get a win32 error message as a string from a win32 error code
get_win32_error_message :: proc(errorCode: win.DWORD) -> string {
	// Flags for FormatMessage
	flags: u32 =
		win.FORMAT_MESSAGE_ALLOCATE_BUFFER |
		win.FORMAT_MESSAGE_FROM_SYSTEM |
		win.FORMAT_MESSAGE_IGNORE_INSERTS

	lpBuffer: win.LPWSTR = nil
	buffer_size := win.FormatMessageW(
		flags,
		nil, // lpSource (not used with FORMAT_MESSAGE_FROM_SYSTEM)
		errorCode,
		0, // dwLanguageId (0 for neutral language)
		cast(^u16)&lpBuffer, // Pass the address of the buffer pointer
		0, // nSize (0 when using FORMAT_MESSAGE_ALLOCATE_BUFFER)
		nil, // Arguments (not used with FORMAT_MESSAGE_IGNORE_INSERTS)
	)

	if buffer_size == 0 {
		return fmt.aprintf("Unknown error (code: %d)", errorCode)
	}

	message_u16 := slice.from_ptr(lpBuffer, int(buffer_size))

	message_utf8, err := win.utf16_to_utf8(message_u16)
	if err != nil {
		win.LocalFree(cast(win.HANDLE)lpBuffer) // for some reason sys/windows doesn't have HLOCAL which might couse issues here
		return fmt.aprintf(
			"Failed to format error message (code: %d), UTF-8 conversion failed",
			errorCode,
		)
	}

	win.LocalFree(cast(win.HANDLE)lpBuffer)

	return strings.trim_space(message_utf8)
}

get_window_title :: proc(handle: win.HWND) -> Maybe(string) {
	lpBuffer := make([]u16, 1024)
    defer delete(lpBuffer)
	len := win.GetWindowTextW(handle, slice.as_ptr(lpBuffer), 1024)
	if len == 0 {
        log.debug("could not get window title")
		return nil
	}

	title_utf8, err := win.utf16_to_utf8(lpBuffer)
    if err != nil {
        log.error(err)
        return nil
    }

    return strings.trim_space(title_utf8)
}

@(deprecated = "currently unused")
get_parent_pid :: proc(pid: win.DWORD) -> Maybe(win.DWORD) {
	h_snapshot := win.CreateToolhelp32Snapshot(win.TH32CS_SNAPPROCESS, 0)
	if h_snapshot == win.INVALID_HANDLE_VALUE {
		log.errorf(
			"CreateToolhelp32Snapshot failed: %s",
			get_win32_error_message(win.GetLastError()),
		)
		return nil
	}
	defer win.CloseHandle(h_snapshot)

	pe: win.PROCESSENTRY32W
	pe.dwSize = size_of(win.PROCESSENTRY32W)

	if win.Process32FirstW(h_snapshot, &pe) == win.TRUE {
		for {
			if pe.th32ProcessID == pid {
				return pe.th32ParentProcessID
			}
			if win.Process32NextW(h_snapshot, &pe) == win.FALSE {
				break
			}
		}
	}

	return nil
}

@(deprecated = "currently unused")
get_child_pids :: proc(pid: win.DWORD) -> [dynamic]win.DWORD {
	children := [dynamic]win.DWORD{}

	h_snapshot := win.CreateToolhelp32Snapshot(win.TH32CS_SNAPPROCESS, 0)
	if h_snapshot == win.INVALID_HANDLE_VALUE {
		log.errorf(
			"CreateToolhelp32Snapshot failed: %s",
			get_win32_error_message(win.GetLastError()),
		)
		return children
	}
	defer win.CloseHandle(h_snapshot)

	pe: win.PROCESSENTRY32W
	pe.dwSize = size_of(win.PROCESSENTRY32W)

	if win.Process32FirstW(h_snapshot, &pe) == win.TRUE {
		for {
			if pe.th32ParentProcessID == pid {
				append(&children, pe.th32ProcessID)
			}
			if win.Process32NextW(h_snapshot, &pe) == win.FALSE {
				break
			}
		}
	}

	return children
}
