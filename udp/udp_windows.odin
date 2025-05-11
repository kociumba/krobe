package udp

import win "core:sys/windows"

UdpEndpointInfo :: struct {
	local_addr:  win.DWORD,
	local_port:  win.DWORD,
	remote_addr: win.DWORD,
	remote_port: win.DWORD,
	pid:         win.DWORD,
}

UdpEndpoints :: struct {
    count: win.DWORD,
    endpoints: ^UdpEndpointInfo
}

foreign import lib "../bin/krobe.lib"
foreign lib {
    get_udp_endpoints :: proc() -> ^UdpEndpoints ---
    free_udp_endpoints :: proc(endpoints: ^UdpEndpoints) ---
}


