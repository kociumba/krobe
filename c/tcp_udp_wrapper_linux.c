#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <dirent.h>
#include <ctype.h>

// TCP state values - equivalent to the Windows definitions
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

// Structure to hold TCP connection information
typedef struct {
    uint32_t state;        // TCP connection state
    uint32_t local_addr;   // Local address in network byte order
    uint16_t local_port;   // Local port in host byte order
    uint32_t remote_addr;  // Remote address in network byte order
    uint16_t remote_port;  // Remote port in host byte order
    uint32_t pid;          // Process ID
} TcpConnectionInfo;

// Structure to hold all TCP connections
typedef struct {
    uint32_t count;              // Number of connections
    TcpConnectionInfo* connections; // Array of connections
} TcpConnections;

// Structure to hold UDP endpoint information
typedef struct {
    uint32_t local_addr;   // Local address in network byte order
    uint16_t local_port;   // Local port in host byte order
    uint32_t remote_addr;  // Remote address in network byte order (0 for UDP listeners)
    uint16_t remote_port;  // Remote port in host byte order (0 for UDP listeners)
    uint32_t pid;          // Process ID
} UdpEndpointInfo;

// Structure to hold all UDP endpoints
typedef struct {
    uint32_t count;             // Number of endpoints
    UdpEndpointInfo* endpoints; // Array of endpoints
} UdpEndpoints;

// Helper function to convert hex string to integer
unsigned int hex_to_int(const char *hex) {
    unsigned int val = 0;
    while (*hex) {
        char byte = *hex++;
        if (byte >= '0' && byte <= '9') byte = byte - '0';
        else if (byte >= 'a' && byte <= 'f') byte = byte - 'a' + 10;
        else if (byte >= 'A' && byte <= 'F') byte = byte - 'A' + 10;
        else continue; // Skip non-hex chars
        val = (val << 4) | (byte & 0xF);
    }
    return val;
}

// Helper function to find the PID owning a socket inode
int find_pid_of_inode(unsigned int inode) {
    DIR *dir;
    struct dirent *entry;
    char path[256];
    char link[256];
    int pid = -1;
    
    // Iterate through all processes
    if ((dir = opendir("/proc")) != NULL) {
        while ((entry = readdir(dir)) != NULL) {
            if (isdigit(entry->d_name[0])) {
                snprintf(path, sizeof(path), "/proc/%s/fd", entry->d_name);
                DIR *fd_dir;
                struct dirent *fd_entry;
                
                if ((fd_dir = opendir(path)) != NULL) {
                    while ((fd_entry = readdir(fd_dir)) != NULL) {
                        snprintf(path, sizeof(path), "/proc/%s/fd/%s", 
                                entry->d_name, fd_entry->d_name);
                        
                        ssize_t len = readlink(path, link, sizeof(link) - 1);
                        if (len != -1) {
                            link[len] = '\0';
                            
                            unsigned int fd_inode;
                            if (sscanf(link, "socket:[%u]", &fd_inode) == 1) {
                                if (fd_inode == inode) {
                                    pid = atoi(entry->d_name);
                                    break;
                                }
                            }
                        }
                    }
                    closedir(fd_dir);
                }
                
                if (pid != -1) break;
            }
        }
        closedir(dir);
    }
    
    return pid;
}

// Function to get TCP connection info
TcpConnections* get_tcp_connections() {
    FILE *fp;
    char line[512];
    uint32_t result_count = 0;
    TcpConnections* result = (TcpConnections*)malloc(sizeof(TcpConnections));
    
    if (!result) return NULL;
    
    result->count = 0;
    result->connections = NULL;
    
    if ((fp = fopen("/proc/net/tcp", "r")) == NULL) {
        free(result);
        return NULL;
    }
    
    // Skip header line
    fgets(line, sizeof(line), fp);
    
    // First pass: count lines
    while (fgets(line, sizeof(line), fp) != NULL) {
        result_count++;
    }
    
    // Allocate memory for connections
    result->connections = (TcpConnectionInfo*)malloc(result_count * sizeof(TcpConnectionInfo));
    if (!result->connections) {
        fclose(fp);
        free(result);
        return NULL;
    }
    
    // Second pass: parse lines
    rewind(fp);
    fgets(line, sizeof(line), fp);
    
    uint32_t idx = 0;
    while (fgets(line, sizeof(line), fp) != NULL && idx < result_count) {
        unsigned int local_addr, local_port;
        unsigned int remote_addr, remote_port;
        unsigned int state, inode;
        
        sscanf(line, "%*d: %x:%x %x:%x %x %*x:%*x %*x:%*x %*x %*d %*d %u",
               &local_addr, &local_port,
               &remote_addr, &remote_port,
               &state, &inode);
        
        result->connections[idx].state = state + 1; // +1 to match Windows values
        result->connections[idx].local_addr = ntohl(local_addr);
        result->connections[idx].local_port = local_port;
        result->connections[idx].remote_addr = ntohl(remote_addr);
        result->connections[idx].remote_port = remote_port;
        result->connections[idx].pid = find_pid_of_inode(inode);
        
        idx++;
    }
    
    fclose(fp);
    result->count = idx;
    return result;
}

// Function to free TCP connections
void free_tcp_connections(TcpConnections* connections) {
    if (connections) {
        free(connections->connections);
        free(connections);
    }
}

// Function to get UDP endpoint info
UdpEndpoints* get_udp_endpoints() {
    FILE *fp;
    char line[512];
    uint32_t result_count = 0;
    UdpEndpoints* result = (UdpEndpoints*)malloc(sizeof(UdpEndpoints));
    
    if (!result) return NULL;
    
    result->count = 0;
    result->endpoints = NULL;
    
    if ((fp = fopen("/proc/net/udp", "r")) == NULL) {
        free(result);
        return NULL;
    }
    
    // Skip header line
    fgets(line, sizeof(line), fp);
    
    // First pass: count lines
    while (fgets(line, sizeof(line), fp) != NULL) {
        result_count++;
    }
    
    // Allocate memory for endpoints
    result->endpoints = (UdpEndpointInfo*)malloc(result_count * sizeof(UdpEndpointInfo));
    if (!result->endpoints) {
        fclose(fp);
        free(result);
        return NULL;
    }
    
    // Second pass: parse lines
    rewind(fp);
    fgets(line, sizeof(line), fp);
    
    uint32_t idx = 0;
    while (fgets(line, sizeof(line), fp) != NULL && idx < result_count) {
        unsigned int local_addr, local_port;
        unsigned int remote_addr, remote_port;
        unsigned int inode;
        
        sscanf(line, "%*d: %x:%x %x:%x %*x %*x:%*x %*x:%*x %*x %*d %*d %u",
               &local_addr, &local_port,
               &remote_addr, &remote_port,
               &inode);
        
        result->endpoints[idx].local_addr = ntohl(local_addr);
        result->endpoints[idx].local_port = local_port;
        result->endpoints[idx].remote_addr = ntohl(remote_addr);
        result->endpoints[idx].remote_port = remote_port;
        result->endpoints[idx].pid = find_pid_of_inode(inode);
        
        idx++;
    }
    
    fclose(fp);
    result->count = idx;
    return result;
}

// Function to free UDP endpoints
void free_udp_endpoints(UdpEndpoints* endpoints) {
    if (endpoints) {
        free(endpoints->endpoints);
        free(endpoints);
    }
}

// Helper function to convert state number to string
const char* get_tcp_state_string(int state) {
    switch (state) {
        case TCP_STATE_CLOSED:       return "CLOSED";
        case TCP_STATE_LISTEN:       return "LISTEN";
        case TCP_STATE_SYN_SENT:     return "SYN_SENT";
        case TCP_STATE_SYN_RCVD:     return "SYN_RCVD";
        case TCP_STATE_ESTAB:        return "ESTABLISHED";
        case TCP_STATE_FIN_WAIT1:    return "FIN_WAIT1";
        case TCP_STATE_FIN_WAIT2:    return "FIN_WAIT2";
        case TCP_STATE_CLOSE_WAIT:   return "CLOSE_WAIT";
        case TCP_STATE_CLOSING:      return "CLOSING";
        case TCP_STATE_LAST_ACK:     return "LAST_ACK";
        case TCP_STATE_TIME_WAIT:    return "TIME_WAIT";
        case TCP_STATE_DELETE_TCB:   return "DELETE_TCB";
        default:                     return "UNKNOWN";
    }
}

// Helper function to print TCP connection info
void print_tcp_connections(TcpConnections* connections) {
    if (!connections) return;
    
    printf("Total TCP connections: %u\n", connections->count);
    printf("------------------------------------------------------\n");
    printf("  Local Address:Port    Remote Address:Port    State    PID\n");
    printf("------------------------------------------------------\n");
    
    for (uint32_t i = 0; i < connections->count; i++) {
        struct in_addr local_addr, remote_addr;
        char local_ip[INET_ADDRSTRLEN], remote_ip[INET_ADDRSTRLEN];
        
        local_addr.s_addr = htonl(connections->connections[i].local_addr);
        remote_addr.s_addr = htonl(connections->connections[i].remote_addr);
        
        inet_ntop(AF_INET, &local_addr, local_ip, sizeof(local_ip));
        inet_ntop(AF_INET, &remote_addr, remote_ip, sizeof(remote_ip));
        
        printf("%15s:%-5d %15s:%-5d %12s %5d\n",
            local_ip, connections->connections[i].local_port,
            remote_ip, connections->connections[i].remote_port,
            get_tcp_state_string(connections->connections[i].state),
            connections->connections[i].pid);
    }
}

// Helper function to print UDP endpoint info
void print_udp_endpoints(UdpEndpoints* endpoints) {
    if (!endpoints) return;
    
    printf("Total UDP endpoints: %u\n", endpoints->count);
    printf("----------------------------------------------\n");
    printf("  Local Address:Port      State       PID\n");
    printf("----------------------------------------------\n");
    
    for (uint32_t i = 0; i < endpoints->count; i++) {
        struct in_addr local_addr;
        char local_ip[INET_ADDRSTRLEN];
        
        local_addr.s_addr = htonl(endpoints->endpoints[i].local_addr);
        inet_ntop(AF_INET, &local_addr, local_ip, sizeof(local_ip));
        
        printf("%15s:%-5d    LISTENING   %5d\n",
            local_ip, 
            endpoints->endpoints[i].local_port,
            endpoints->endpoints[i].pid);
    }
}

#ifdef TEST_CODE
int main() {
    TcpConnections* tcp_connections = get_tcp_connections();
    print_tcp_connections(tcp_connections);
    free_tcp_connections(tcp_connections);
    
    printf("\n");
    UdpEndpoints* udp_endpoints = get_udp_endpoints();
    print_udp_endpoints(udp_endpoints);
    free_udp_endpoints(udp_endpoints);
    return 0;
}
#endif
