// Copyright 2024 Dolphin Design
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Licensed under the Solderpad Hardware License v 2.1 (the "License");
// you may not use this file except in compliance with the License, or,
// at your option, the Apache License version 2.0.
// You may obtain a copy of the License at
//
// https://solderpad.org/licenses/SHL-2.1/
//
// Unless required by applicable law or agreed to in writing, any work
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

//
// AXI memory
//

module ram_axi(
    clk,
    rst_n,
    // AXI write address channel
    axi_awvalid,
    axi_awready,
    axi_awaddr,
    axi_awsize,
    axi_awburst,
    axi_awcache,
    axi_awprot,
    axi_awid,
    axi_awlen,
    axi_awlock,
    axi_awqos,
    axi_awregion,
    axi_awuser,
    // AXI write data channel
    axi_wvalid,
    axi_wready,
    axi_wlast,
    axi_wdata,
    axi_wstrb,
    axi_wuser,
    // AXI write response channel
    axi_bvalid,
    axi_bready,
    axi_bresp,
    axi_bid,
    axi_buser,
    // AXI read address channel
    axi_arvalid,
    axi_arready,
    axi_araddr,
    axi_arsize,
    axi_arburst,
    axi_arcache,
    axi_arprot,
    axi_arid,
    axi_arlen,
    axi_arlock,
    axi_arqos,
    axi_arregion,
    axi_aruser,
    // AXI read data channel
    axi_rvalid,
    axi_rready,
    axi_rlast,
    axi_rdata,
    axi_rresp,
    axi_rid,
    axi_ruser
);

    parameter PARAMETER_ADDRESS_SIZE = 1;
    parameter PARAMETER_WORD_SIZE    = 1;
    parameter PARAMETER_USER_SIZE    = 1;
    parameter PARAMETER_ID_SIZE      = 1;

    parameter PARAMETER_STROBE_SIZE  = PARAMETER_WORD_SIZE/8;
    parameter PARAMETER_ADDR_LSBS    = $clog2(PARAMETER_STROBE_SIZE);
    parameter PARAMETER_RAM_SIZE     = 1 << (30); //to overcome "Error-[MTL] Memory Too Large" failure during VCS compilation. Memory size limits in simulator (VCS & NCSIM): VCS limits 2GB.

    parameter PARAMETER_DATA_FILENAME = "";

    input   clk;
    input   rst_n;

    input                                axi_awvalid;
    output                               axi_awready;
    input   [PARAMETER_ADDRESS_SIZE-1:0] axi_awaddr;
    input   [2:0]                        axi_awsize;
    input   [1:0]                        axi_awburst;
    input   [3:0]                        axi_awcache;
    input   [2:0]                        axi_awprot;
    input   [PARAMETER_ID_SIZE-1:0]      axi_awid;
    input   [7:0]                        axi_awlen;
    input                                axi_awlock;
    input   [3:0]                        axi_awqos;
    input   [3:0]                        axi_awregion;
    input   [PARAMETER_USER_SIZE-1:0]    axi_awuser;
    input                                axi_wvalid;
    output                               axi_wready;
    input                                axi_wlast;
    input   [PARAMETER_WORD_SIZE-1:0]    axi_wdata;
    input   [PARAMETER_STROBE_SIZE-1:0] axi_wstrb;
    input   [PARAMETER_USER_SIZE-1:0]    axi_wuser;
    output                               axi_bvalid;
    input                                axi_bready;
    output  [1:0]                        axi_bresp;
    output  [PARAMETER_ID_SIZE-1:0]      axi_bid;
    output  [PARAMETER_USER_SIZE-1:0]    axi_buser;

    input                                axi_arvalid;
    output                               axi_arready;
    input   [PARAMETER_ADDRESS_SIZE-1:0] axi_araddr;
    input   [2:0]                        axi_arsize;
    input   [1:0]                        axi_arburst;
    input   [3:0]                        axi_arcache;
    input   [2:0]                        axi_arprot;
    input   [PARAMETER_ID_SIZE-1:0]      axi_arid;
    input   [7:0]                        axi_arlen;
    input                                axi_arlock;
    input   [3:0]                        axi_arqos;
    input   [3:0]                        axi_arregion;
    input   [PARAMETER_USER_SIZE-1:0]    axi_aruser;
    output                               axi_rvalid;
    input                                axi_rready;
    output                               axi_rlast;
    output  [PARAMETER_WORD_SIZE-1:0]    axi_rdata;
    output  [1:0]                        axi_rresp;
    output  [PARAMETER_ID_SIZE-1:0]      axi_rid;
    output  [PARAMETER_USER_SIZE-1:0]    axi_ruser;


    bit /*sparse*/ [7:0] ram_array [PARAMETER_RAM_SIZE-1:0]; //to overcome "Error-[MTL] Memory Too Large" failure during VCS compilation, use bit data type.

    localparam [0:0] READ_STATE_IDLE  = 1'd0;
    localparam [0:0] READ_STATE_BURST = 1'd1;

    reg [0:0] r_read_state;
    reg [0:0] read_state_next;

    localparam [1:0] WRITE_STATE_IDLE  = 2'd0;
    localparam [1:0] WRITE_STATE_BURST = 2'd1;
    localparam [1:0] WRITE_STATE_RESP  = 2'd2;

    reg [1:0] r_write_state;
    reg [1:0] write_state_next;

    reg mem_wr_en;
    reg mem_rd_en;

    reg [PARAMETER_ID_SIZE-1:0] r_read_id;
    reg [PARAMETER_ID_SIZE-1:0] read_id_next;
    reg [PARAMETER_ADDRESS_SIZE-1:0] r_read_addr;
    reg [PARAMETER_ADDRESS_SIZE-1:0] read_addr_next;
    reg [7:0] r_read_count;
    reg [7:0] read_count_next;
    reg [2:0] r_read_size;
    reg [2:0] read_size_next;
    reg [1:0] r_read_burst;
    reg [1:0] read_burst_next;
    reg [PARAMETER_ID_SIZE-1:0] r_write_id;
    reg [PARAMETER_ID_SIZE-1:0] write_id_next;
    reg [PARAMETER_ADDRESS_SIZE-1:0] r_write_addr;
    reg [PARAMETER_ADDRESS_SIZE-1:0] write_addr_next;
    reg [7:0] r_write_count;
    reg [7:0] write_count_next;
    reg [2:0] r_write_size;
    reg [2:0] write_size_next;
    reg [1:0] r_write_burst;
    reg [1:0] write_burst_next;

    reg r_axi_awready;
    reg axi_awready_next;
    reg r_axi_wready;
    reg axi_wready_next;
    reg [PARAMETER_ID_SIZE-1:0] r_axi_bid;
    reg [PARAMETER_ID_SIZE-1:0] axi_bid_next;
    reg r_axi_bvalid;
    reg axi_bvalid_next;
    reg r_axi_arready;
    reg axi_arready_next;
    reg [PARAMETER_ID_SIZE-1:0] r_axi_rid;
    reg [PARAMETER_ID_SIZE-1:0] axi_rid_next;
    reg [PARAMETER_WORD_SIZE-1:0] r_axi_rdata;
    reg [PARAMETER_WORD_SIZE-1:0] axi_rdata_next;
    reg r_axi_rlast;
    reg axi_rlast_next;
    reg r_axi_rvalid;
    reg axi_rvalid_next;

    assign axi_awready = r_axi_awready;
    assign axi_wready  = r_axi_wready;
    assign axi_bid     = r_axi_bid;
    assign axi_bresp   = 2'b00;
    assign axi_bvalid  = r_axi_bvalid;
    assign axi_arready = r_axi_arready;
    assign axi_rid     = r_axi_rid;
    assign axi_rdata   = r_axi_rdata;
    assign axi_rresp   = 2'b00;
    assign axi_rlast   = r_axi_rlast;
    assign axi_rvalid  = r_axi_rvalid;

    //-------------------------------------------------------
    // Reading test.dat initially and at every reset
    //-------------------------------------------------------
    initial begin
        if (PARAMETER_DATA_FILENAME != "" ) begin
            $readmemh(PARAMETER_DATA_FILENAME, ram_array);
            $display("RAM loaded with file %s", PARAMETER_DATA_FILENAME);
        end 
        else begin
            for (longint i = 0; i < 1<<PARAMETER_ADDRESS_SIZE+2; i++) begin
                ram_array[i] = {PARAMETER_WORD_SIZE{1'b0}};
            end
            $display("RAM initialized to 0");
        end
    end

    // Initialization of memory array at reset
    always @(negedge rst_n or posedge clk) begin
        if (rst_n == 1'b0) begin
            if (PARAMETER_DATA_FILENAME != "" ) begin
                $readmemh(PARAMETER_DATA_FILENAME, ram_array);
            end 
            else begin
                for (longint i = 0; i < 1<<PARAMETER_ADDRESS_SIZE+2; i++) begin
                    ram_array[i] = {PARAMETER_WORD_SIZE{1'b0}};
                end
            end
        end
    end

    always @(*) begin
        write_state_next = WRITE_STATE_IDLE;

        mem_wr_en = 1'b0;

        write_id_next    = r_write_id;
        write_addr_next  = r_write_addr;
        write_count_next = r_write_count;
        write_size_next  = r_write_size;
        write_burst_next = r_write_burst;

        axi_awready_next = 1'b0;
        axi_wready_next  = 1'b0;
        axi_bid_next     = r_axi_bid;
        axi_bvalid_next  = r_axi_bvalid && !axi_bready;

        case (r_write_state)
            WRITE_STATE_IDLE: begin
                axi_awready_next = 1'b1;

                if (axi_awready && axi_awvalid) begin
                    write_id_next    = axi_awid;
                    write_addr_next  = {axi_awaddr[PARAMETER_ADDRESS_SIZE-1:PARAMETER_ADDR_LSBS], {PARAMETER_ADDR_LSBS{1'b0}}};
                    write_count_next = axi_awlen;
                    write_size_next  = axi_awsize;
                    write_burst_next = axi_awburst;

                    axi_awready_next = 1'b0;
                    axi_wready_next  = 1'b1;
                    write_state_next = WRITE_STATE_BURST;
                end else begin
                    write_state_next = WRITE_STATE_IDLE;
                end
            end
            WRITE_STATE_BURST: begin
                axi_wready_next = 1'b1;

                if (axi_wready && axi_wvalid) begin
                    mem_wr_en = 1'b1;
                    if (r_write_burst != 2'b00) begin
                        write_addr_next = r_write_addr + (1 << r_write_size);
                    end
                    write_count_next = r_write_count - 1;
                    if (r_write_count > 0) begin
                        write_state_next = WRITE_STATE_BURST;
                    end else begin
                        axi_wready_next = 1'b0;
                        if (axi_bready || !axi_bvalid) begin
                            axi_bid_next     = r_write_id;
                            axi_bvalid_next  = 1'b1;
                            axi_awready_next = 1'b1;
                            write_state_next = WRITE_STATE_IDLE;
                        end else begin
                            write_state_next = WRITE_STATE_RESP;
                        end
                    end
                end else begin
                    write_state_next = WRITE_STATE_BURST;
                end
            end
            WRITE_STATE_RESP: begin
                if (axi_bready || !axi_bvalid) begin
                    axi_bid_next     = r_write_id;
                    axi_bvalid_next  = 1'b1;
                    axi_awready_next = 1'b1;
                    write_state_next = WRITE_STATE_IDLE;
                end else begin
                    write_state_next = WRITE_STATE_RESP;
                end
            end
        endcase
    end

    always @(negedge rst_n or posedge clk) begin
        if (rst_n == 1'b0) begin
            r_write_state <= WRITE_STATE_IDLE;

            r_write_id    <= {PARAMETER_ID_SIZE{1'b0}};
            r_write_addr  <= {PARAMETER_ADDRESS_SIZE{1'b0}};
            r_write_count <= 8'h0;
            r_write_size  <= 3'h0;
            r_write_burst <= 2'h0;

            r_axi_awready <= 1'b0;
            r_axi_wready  <= 1'b0;
            r_axi_bvalid  <= 1'b0;
            r_axi_bid     <= {PARAMETER_ID_SIZE{1'b0}};
        end
        else begin
            r_write_state <= write_state_next;

            r_write_id    <= write_id_next;
            r_write_addr  <= write_addr_next;
            r_write_count <= write_count_next;
            r_write_size  <= write_size_next;
            r_write_burst <= write_burst_next;

            r_axi_awready <= axi_awready_next;
            r_axi_wready  <= axi_wready_next;
            r_axi_bid     <= axi_bid_next;
            r_axi_bvalid  <= axi_bvalid_next;

            for (int i = 0; i < PARAMETER_STROBE_SIZE; i = i + 1) begin
                if (mem_wr_en & axi_wstrb[i]) begin
                    ram_array[r_write_addr + i] <= axi_wdata[8*i +: 8];
                end
            end
        end
    end

    always @(*) begin
        read_state_next = READ_STATE_IDLE;

        mem_rd_en = 1'b0;

        axi_rid_next    = r_axi_rid;
        axi_rlast_next  = r_axi_rlast;
        axi_rvalid_next = r_axi_rvalid && !(axi_rready);

        read_id_next    = r_read_id;
        read_addr_next  = r_read_addr;
        read_count_next = r_read_count;
        read_size_next  = r_read_size;
        read_burst_next = r_read_burst;

        axi_arready_next = 1'b0;

        case (r_read_state)
            READ_STATE_IDLE: begin
                axi_arready_next = 1'b1;

                if (axi_arready && axi_arvalid) begin
                    read_id_next    = axi_arid;
                    read_addr_next  = {axi_araddr[PARAMETER_ADDRESS_SIZE-1:PARAMETER_ADDR_LSBS], {PARAMETER_ADDR_LSBS{1'b0}}};
                    read_count_next = axi_arlen;
                    read_size_next  = axi_arsize;
                    read_burst_next = axi_arburst;

                    axi_arready_next = 1'b0;
                    read_state_next  = READ_STATE_BURST;
                end else begin
                    read_state_next = READ_STATE_IDLE;
                end
            end
            READ_STATE_BURST: begin
                if (axi_rready || !r_axi_rvalid) begin
                    mem_rd_en       = 1'b1;
                    axi_rvalid_next = 1'b1;
                    axi_rid_next    = r_read_id;
                    axi_rlast_next  = r_read_count == 0;
                    if (r_read_burst != 2'b00) begin
                        read_addr_next = r_read_addr + (1 << r_read_size);
                    end
                    read_count_next = r_read_count - 1;
                    if (r_read_count > 0) begin
                        read_state_next = READ_STATE_BURST;
                    end else begin
                        axi_arready_next = 1'b1;
                        read_state_next  = READ_STATE_IDLE;
                    end
                end else begin
                    read_state_next = READ_STATE_BURST;
                end
            end
        endcase
    end

    always @(negedge rst_n or posedge clk) begin
        if (rst_n == 1'b0) begin
            r_read_state  <= READ_STATE_IDLE;

            r_read_id     <= {PARAMETER_ID_SIZE{1'b0}};
            r_read_addr   <= {PARAMETER_ADDRESS_SIZE{1'b0}};
            r_read_count  <= 8'h0;
            r_read_size   <= 3'h0;
            r_read_burst  <= 2'h0;

            r_axi_arready <= 1'b0;
            r_axi_rid     <= {PARAMETER_ID_SIZE{1'b0}};
            r_axi_rlast   <= 1'b0;
            r_axi_rvalid  <= 1'b0;
            r_axi_rdata   <= {PARAMETER_WORD_SIZE{1'b0}};
        end
        else begin
            r_read_state  <= read_state_next;

            r_read_id     <= read_id_next;
            r_read_addr   <= read_addr_next;
            r_read_count  <= read_count_next;
            r_read_size   <= read_size_next;
            r_read_burst  <= read_burst_next;

            r_axi_arready <= axi_arready_next;
            r_axi_rid     <= axi_rid_next;
            r_axi_rlast   <= axi_rlast_next;
            r_axi_rvalid  <= axi_rvalid_next;

            for (int i = 0; i < PARAMETER_STROBE_SIZE; i = i + 1) begin
                if (mem_rd_en) begin
                    r_axi_rdata[8*i +: 8] <= ram_array[r_read_addr + i];
                end
            end
        end
    end

endmodule
