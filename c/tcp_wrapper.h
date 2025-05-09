// this header is redundant and unused, kept in case I want to write some c or c++ code that uses the tcp wrapper
#pragma deprecated(__FILE__)

#ifndef TCP_WRAPPER_H
#define TCP_WRAPPER_H

#include <windows.h>

#ifdef __cplusplus
extern "C" {
#endif

// TCP connection information structure
typedef struct {
    DWORD state;          // TCP connection state
    DWORD local_addr;     // Local address in network byte order
    WORD  local_port;     // Local port in host byte order
    DWORD remote_addr;    // Remote address in network byte order
    WORD  remote_port;    // Remote port in host byte order
    DWORD pid;            // Process ID
} TcpConnectionInfo;

// Structure to hold all connection data
typedef struct {
    DWORD count;                // Number of connections
    TcpConnectionInfo* connections;  // Array of connections
} TcpConnections;

// Function to get TCP connection info (IPv4)
__declspec(dllexport) TcpConnections* get_tcp_connections();

// Function to release the memory allocated by get_tcp_connections
__declspec(dllexport) void free_tcp_connections(TcpConnections* connections);

// Helper function to print TCP connection info (for testing)
__declspec(dllexport) void print_tcp_connections(TcpConnections* connections);

// TCP state constants (from winsock header)
#define TCP_STATE_CLOSED        1
#define TCP_STATE_LISTEN        2
#define TCP_STATE_SYN_SENT      3
#define TCP_STATE_SYN_RCVD      4
#define TCP_STATE_ESTAB         5
#define TCP_STATE_FIN_WAIT1     6
#define TCP_STATE_FIN_WAIT2     7
#define TCP_STATE_CLOSE_WAIT    8
#define TCP_STATE_CLOSING       9
#define TCP_STATE_LAST_ACK      10
#define TCP_STATE_TIME_WAIT     11
#define TCP_STATE_DELETE_TCB    12

#ifdef __cplusplus
}
#endif

#endif // TCP_WRAPPER_H