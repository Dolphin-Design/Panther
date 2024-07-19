`ifndef HIER_ICACHE_PKG
`define HIER_ICACHE_PKG


package hier_icache_pkg;


    function automatic int        log2(int VALUE);
    begin
        log2          = ((VALUE) <= ( 1 ) ? 1 : (VALUE) <= ( 2 ) ? 1 : (VALUE) <= ( 4 ) ? 2 : (VALUE) <= ( 8 ) ? 3 : (VALUE) <= ( 16 ) ? 4 : (VALUE) <= ( 32 )  ? 5 : 6 );
    end
    endfunction

    function automatic int        log2_non_zero(int VALUE);
    begin
        log2_non_zero = ((VALUE) < ( 1 ) ? 1 : (VALUE) < ( 2 ) ? 1 : (VALUE) < ( 4 ) ? 2 : (VALUE)< (8) ? 3:(VALUE) < ( 16 )  ? 4 : (VALUE) < ( 32 )  ? 5 : (VALUE) < ( 64 )  ? 6 : (VALUE) < ( 128 ) ? 7 : (VALUE) < ( 256 ) ? 8 : (VALUE) < ( 512 ) ? 9 : 10);
    end
    endfunction

    function automatic int        log2_size(int VALUE);
    begin
        log2_size     = ((VALUE) <= ( 1 ) ? 1 : (VALUE) < ( 2 ) ? 1 : (VALUE) < ( 4 ) ? 2 : (VALUE)< (8) ? 3:(VALUE) < ( 16 )  ? 4 : 5 );
    end
    endfunction


    localparam logic [5:0]  ENABLE_ICACHE_ADDR            = 6'b00_0000; //0x00
    localparam logic [5:0]  FLUSH_ICACHE_ADDR             = 6'b00_0001; //0x04
    localparam logic [5:0]  FLUSH_L1_ONLY_ADDR            = 6'b00_0010; //0x08
    localparam logic [5:0]  SEL_FLUSH_ICACHE_ADDR         = 6'b00_0011; //0x0C
    localparam logic [5:0]  CLEAR_CNTS_ADDR               = 6'b00_0100; //0x10
    localparam logic [5:0]  ENABLE_CNTS_ADDR              = 6'b00_0101; //0x14
    localparam logic [5:0]  ENABLE_L1_L15_PREFETCH_ADDR   = 6'b00_0111; //0x1C

    localparam logic        FROM_PIPE                     = 1'b0      ;
    localparam logic        FROM_FIFO                     = 1'b1      ;
    localparam logic        DEBUG_INFO                    = 1'b0      ;

endpackage


`endif
