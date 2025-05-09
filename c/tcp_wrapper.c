#include <winsock2.h>
#include <windows.h>
#include <ws2ipdef.h>
#include <iphlpapi.h>
#include <stdlib.h>
#include <stdio.h>

#pragma comment(lib, "iphlpapi.lib")
#pragma comment(lib, "ws2_32.lib")

// structure returned to odin
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
    DWORD count;               // Number of connections
    TcpConnectionInfo* connections;  // Array of connections
} TcpConnections;

// TCP state values for easier reading
const char* get_tcp_state_string(DWORD state) {
    switch (state) {
        case MIB_TCP_STATE_CLOSED:       return "CLOSED";
        case MIB_TCP_STATE_LISTEN:       return "LISTEN";
        case MIB_TCP_STATE_SYN_SENT:     return "SYN_SENT";
        case MIB_TCP_STATE_SYN_RCVD:     return "SYN_RCVD";
        case MIB_TCP_STATE_ESTAB:        return "ESTABLISHED";
        case MIB_TCP_STATE_FIN_WAIT1:    return "FIN_WAIT1";
        case MIB_TCP_STATE_FIN_WAIT2:    return "FIN_WAIT2";
        case MIB_TCP_STATE_CLOSE_WAIT:   return "CLOSE_WAIT";
        case MIB_TCP_STATE_CLOSING:      return "CLOSING";
        case MIB_TCP_STATE_LAST_ACK:     return "LAST_ACK";
        case MIB_TCP_STATE_TIME_WAIT:    return "TIME_WAIT";
        case MIB_TCP_STATE_DELETE_TCB:   return "DELETE_TCB";
        default:                         return "UNKNOWN";
    }
}

// Function to get TCP connection info (IPv4)
__declspec(dllexport) TcpConnections* get_tcp_connections() {
    PMIB_TCPTABLE_OWNER_PID pTcpTable = NULL;
    DWORD dwSize = 0;
    DWORD dwRetVal = 0;
    
    // Initialize dynamic memory for the connections
    TcpConnections* result = (TcpConnections*)malloc(sizeof(TcpConnections));
    if (!result) return NULL;
    
    result->count = 0;
    result->connections = NULL;

    // Make initial call to GetExtendedTcpTable to get required buffer size
    dwRetVal = GetExtendedTcpTable(NULL, &dwSize, TRUE, AF_INET, 
                                  TCP_TABLE_OWNER_PID_ALL, 0);
    
    if (dwRetVal == ERROR_INSUFFICIENT_BUFFER) {
        // Allocate memory for the table
        pTcpTable = (PMIB_TCPTABLE_OWNER_PID)malloc(dwSize);
        if (pTcpTable == NULL) {
            free(result);
            return NULL;
        }

        // Make the actual call to GetExtendedTcpTable
        dwRetVal = GetExtendedTcpTable(pTcpTable, &dwSize, TRUE, AF_INET,
                                      TCP_TABLE_OWNER_PID_ALL, 0);
        
        if (dwRetVal == NO_ERROR) {
            // Get the number of entries
            result->count = pTcpTable->dwNumEntries;
            
            // Allocate memory for connection info
            result->connections = (TcpConnectionInfo*)malloc(
                result->count * sizeof(TcpConnectionInfo));
                
            if (!result->connections) {
                free(pTcpTable);
                free(result);
                return NULL;
            }
            
            // Copy the data from the TCP table to our simpler structure
            for (DWORD i = 0; i < result->count; i++) {
                result->connections[i].state = pTcpTable->table[i].dwState;
                result->connections[i].local_addr = pTcpTable->table[i].dwLocalAddr;
                // Convert from network to host byte order for ports
                result->connections[i].local_port = ntohs((u_short)pTcpTable->table[i].dwLocalPort);
                result->connections[i].remote_addr = pTcpTable->table[i].dwRemoteAddr;
                result->connections[i].remote_port = ntohs((u_short)pTcpTable->table[i].dwRemotePort);
                result->connections[i].pid = pTcpTable->table[i].dwOwningPid;
            }
        }
        
        free(pTcpTable);
    }
    
    return result;
}

// Function to release the memory allocated by get_tcp_connections
__declspec(dllexport) void free_tcp_connections(TcpConnections* connections) {
    if (connections) {
        // Free the array of connections
        if (connections->connections) {
            free(connections->connections);
        }
        // Free the main structure
        free(connections);
    }
}

// Helper function to print TCP connection info (for testing)
__declspec(dllexport) void print_tcp_connections(TcpConnections* connections) {
    if (!connections) return;
    
    printf("Total TCP connections: %ld\n", connections->count);
    printf("------------------------------------------------------\n");
    printf("  Local Address:Port    Remote Address:Port    State    PID\n");
    printf("------------------------------------------------------\n");
    
    for (DWORD i = 0; i < connections->count; i++) {
        struct in_addr local_addr, remote_addr;
        char local_ip[INET_ADDRSTRLEN], remote_ip[INET_ADDRSTRLEN];
        
        // Convert addresses to readable format
        local_addr.s_addr = connections->connections[i].local_addr;
        remote_addr.s_addr = connections->connections[i].remote_addr;
        
        inet_ntop(AF_INET, &local_addr, local_ip, sizeof(local_ip));
        inet_ntop(AF_INET, &remote_addr, remote_ip, sizeof(remote_ip));
        
        printf("%15s:%-5d %15s:%-5d %12s %5ld\n",
            local_ip, connections->connections[i].local_port,
            remote_ip, connections->connections[i].remote_port,
            get_tcp_state_string(connections->connections[i].state),
            connections->connections[i].pid);
    }
}

// Simple test function to verify the wrapper works correctly
#ifdef TEST_WRAPPER
int main() {
    // Initialize Winsock (required for some helper functions)
    WSADATA wsaData;
    WSAStartup(MAKEWORD(2, 2), &wsaData);
    
    // Get and print TCP connections
    TcpConnections* connections = get_tcp_connections();
    print_tcp_connections(connections);
    
    // Clean up
    free_tcp_connections(connections);
    WSACleanup();
    
    return 0;
}
#endif