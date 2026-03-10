
package eth_pkg;

    typedef struct packed {
        logic [47:0] mac_dst_addr;
        logic [47:0] mac_src_addr;
        logic [15:0] eth_type;
        logic [1500*8-1:0] payload;
        logic [11:0] payload_len;
    } ethernet_packet_t;
    
    parameter MAX_FRAME_BYTELENGTH = 1518; 

endpackage

