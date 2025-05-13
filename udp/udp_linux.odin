package udp

import "core:c"

UdpEndpointInfo :: struct {
    local_addr: c.uint32_t,
    local_port: c.uint16_t,
    remote_addr: c.uint32_t,
    remote_port: c.uint16_t,
    pid: c.uint32_t
}

UdpEndpoints :: struct {
    count: c.uint32_t,
    endpoints: ^UdpEndpointInfo
}

foreign import lib "../bin/krobe.a"
foreign lib {
    get_udp_endpoints :: proc() -> ^UdpEndpoints ---
    free_udp_endpoints :: proc(endpoints: ^UdpEndpoints) ---
}