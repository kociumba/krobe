package utils

import "core:c"
import "core:fmt"
import "core:log"
import "core:slice"
import "core:strings"
import "core:sys/posix"

get_proc_info :: proc(pid: u32) -> Maybe(string) {
	// Build the path to the process's executable in the /proc filesystem
	proc_path := fmt.tprintf("/proc/%d/exe", pid)

	buffer := make([]byte, 4096)
	prt_buffer := slice.as_ptr(buffer)

	bytes_read := posix.readlink(strings.clone_to_cstring(proc_path), prt_buffer, 4096)

	if bytes_read < 0 {
		err := posix.Errno(-bytes_read)

		if err == posix.Errno.EACCES {
			log.errorf("Permission denied for PID %d: you may need to run as root", pid)
		} else {
			err_str := posix.strerror(err)
			log.errorf("Failed to read process info for PID %d: %s", pid, err_str)
		}
		return nil
	}

	if bytes_read > 0 {
		buffer = slice.from_ptr(prt_buffer, bytes_read)
		path := string(buffer[:bytes_read])
		return path
	}

	return nil
}
