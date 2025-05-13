#include <winsock2.h>
#include <windows.h>
#include <ws2ipdef.h>
#include <iphlpapi.h>
#include <stdlib.h>
#include <stdio.h>

#pragma comment(lib, "iphlpapi.lib")
#pragma comment(lib, "ws2_32.lib")

// Structure returned to Odin
typedef struct {
    DWORD local_addr;     // Local address in network byte order
    WORD  local_port;     // Local port in host byte order
    DWORD remote_addr;    // Remote address in network byte order (0 for UDP listeners)
    WORD  remote_port;    // Remote port in host byte order (0 for UDP listeners)
    DWORD pid;            // Process ID
} UdpEndpointInfo;

// Structure to hold all UDP endpoint data
typedef struct {
    DWORD count;               // Number of endpoints
    UdpEndpointInfo* endpoints;  // Array of endpoints
} UdpEndpoints;

// Function to get UDP endpoint info (IPv4)
__declspec(dllexport) UdpEndpoints* get_udp_endpoints() {
    PMIB_UDPTABLE_OWNER_PID pUdpTable = NULL;
    DWORD dwSize = 0;
    DWORD dwRetVal = 0;
    
    UdpEndpoints* result = (UdpEndpoints*)malloc(sizeof(UdpEndpoints));
    if (!result) return NULL;
    
    result->count = 0;
    result->endpoints = NULL;

    // Make an initial call to GetExtendedUdpTable to get the necessary size
    dwRetVal = GetExtendedUdpTable(NULL, &dwSize, TRUE, AF_INET, 
                                  UDP_TABLE_OWNER_PID, 0);
    
    if (dwRetVal == ERROR_INSUFFICIENT_BUFFER) {
        pUdpTable = (PMIB_UDPTABLE_OWNER_PID)malloc(dwSize);
        if (pUdpTable == NULL) {
            free(result);
            return NULL;
        }

        // Make a second call to GetExtendedUdpTable to get the actual data
        dwRetVal = GetExtendedUdpTable(pUdpTable, &dwSize, TRUE, AF_INET,
                                      UDP_TABLE_OWNER_PID, 0);
        
        if (dwRetVal == NO_ERROR) {
            result->count = pUdpTable->dwNumEntries;
            
            result->endpoints = (UdpEndpointInfo*)malloc(
                result->count * sizeof(UdpEndpointInfo));
                
            if (!result->endpoints) {
                free(pUdpTable);
                free(result);
                return NULL;
            }
            
            for (DWORD i = 0; i < result->count; i++) {
                result->endpoints[i].local_addr = pUdpTable->table[i].dwLocalAddr;
                // Convert from network to host byte order for ports
                result->endpoints[i].local_port = ntohs((u_short)pUdpTable->table[i].dwLocalPort);
                // UDP doesn't track remote addresses/ports as TCP does,
                // so we set these to 0 for UDP endpoints
                result->endpoints[i].remote_addr = 0;
                result->endpoints[i].remote_port = 0;
                result->endpoints[i].pid = pUdpTable->table[i].dwOwningPid;
            }
        }
        
        free(pUdpTable);
    }
    
    return result;
}

// Function to release the memory allocated by get_udp_endpoints
__declspec(dllexport) void free_udp_endpoints(UdpEndpoints* endpoints) {
    if (endpoints) {  
        if (endpoints->endpoints) {
            free(endpoints->endpoints);
        }
        free(endpoints);
    }
}

// Helper function to print UDP endpoint info (for testing)
__declspec(dllexport) void print_udp_endpoints(UdpEndpoints* endpoints) {
    if (!endpoints) return;
    
    printf("Total UDP endpoints: %ld\n", endpoints->count);
    printf("----------------------------------------------\n");
    printf("  Local Address:Port      State       PID\n");
    printf("----------------------------------------------\n");
    
    for (DWORD i = 0; i < endpoints->count; i++) {
        struct in_addr local_addr;
        char local_ip[INET_ADDRSTRLEN];
        
        // Convert addresses to readable format
        local_addr.s_addr = endpoints->endpoints[i].local_addr;
        inet_ntop(AF_INET, &local_addr, local_ip, sizeof(local_ip));
        
        printf("%15s:%-5d    LISTENING   %5ld\n",
            local_ip, 
            endpoints->endpoints[i].local_port,
            endpoints->endpoints[i].pid);
    }
}

// Simple test function to verify the wrapper works correctly
#ifdef TEST_WRAPPER
int main() {
    // Initialize Winsock (required for some helper functions)
    WSADATA wsaData;
    WSAStartup(MAKEWORD(2, 2), &wsaData);
    
    // Get and print UDP endpoints
    UdpEndpoints* endpoints = get_udp_endpoints();
    print_udp_endpoints(endpoints);
    
    // Clean up
    free_udp_endpoints(endpoints);
    WSACleanup();
    
    return 0;
}
#endif