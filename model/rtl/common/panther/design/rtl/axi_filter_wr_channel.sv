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

module axi_filter_wr_channel #(
    parameter int                        AXI_ADDR_WIDTH            = 32,
    parameter int                        AXI_DATA_WIDTH            = 64,
    parameter int                        AXI_STRB_WIDTH            = AXI_DATA_WIDTH/8,
    parameter int                        AXI_ID_WIDTH              =  7,
    parameter int                        AXI_USER_WIDTH            =  4,
    parameter int                        NBR_RANGE                 =  1,
    parameter int                        NBR_OUTSTANDING_REQ       =  4,
    parameter int                        AXI_LOOK_BITS             =  4
) (
    input  logic                             i_clk,
    input  logic                             i_rst_n,
    input  logic                             i_scan_ckgt_enable,

    input   logic [AXI_ADDR_WIDTH-1:0]       START_ADDR[NBR_RANGE-1:0],
    input   logic [AXI_ADDR_WIDTH-1:0]       STOP_ADDR [NBR_RANGE-1:0],

    // INPUT
    // WRITE ADDRESS CHANNEL
    input  logic                             axi_in_aw_valid_i ,
    input  logic [AXI_ADDR_WIDTH-1:0]        axi_in_aw_addr_i  ,
    input  logic [2:0]                       axi_in_aw_prot_i  ,
    input  logic [3:0]                       axi_in_aw_region_i,
    input  logic [7:0]                       axi_in_aw_len_i   ,
    input  logic [2:0]                       axi_in_aw_size_i  ,
    input  logic [5:0]                       axi_in_aw_atop_i  ,
    input  logic [1:0]                       axi_in_aw_burst_i ,
    input  logic                             axi_in_aw_lock_i  ,
    input  logic [3:0]                       axi_in_aw_cache_i ,
    input  logic [3:0]                       axi_in_aw_qos_i   ,
    input  logic [AXI_ID_WIDTH-1:0]          axi_in_aw_id_i    ,
    input  logic [AXI_USER_WIDTH-1:0]        axi_in_aw_user_i  ,
    output logic                             axi_in_aw_ready_o ,

    // WRITE DATA CHANNEL
    input  logic                             axi_in_w_valid_i,
    input  logic [AXI_DATA_WIDTH-1:0]        axi_in_w_data_i ,
    input  logic [AXI_STRB_WIDTH-1:0]        axi_in_w_strb_i ,
    input  logic [AXI_USER_WIDTH-1:0]        axi_in_w_user_i ,
    input  logic                             axi_in_w_last_i ,
    output logic                             axi_in_w_ready_o,

    // WRITE RESPONSE CHANNEL
    output logic                             axi_in_b_valid_o,
    output logic [1:0]                       axi_in_b_resp_o ,
    output logic [AXI_ID_WIDTH-1:0]          axi_in_b_id_o   ,
    output logic [AXI_USER_WIDTH-1:0]        axi_in_b_user_o ,
    input  logic                             axi_in_b_ready_i,

    // OUTPUT
    // WRITE ADDRESS CHANNEL
    output logic                             axi_out_aw_valid_o ,
    output logic [AXI_ADDR_WIDTH-1:0]        axi_out_aw_addr_o  ,
    output logic [2:0]                       axi_out_aw_prot_o  ,
    output logic [3:0]                       axi_out_aw_region_o,
    output logic [7:0]                       axi_out_aw_len_o   ,
    output logic [2:0]                       axi_out_aw_size_o  ,
    output logic [5:0]                       axi_out_aw_atop_o  ,
    output logic [1:0]                       axi_out_aw_burst_o ,
    output logic                             axi_out_aw_lock_o  ,
    output logic [3:0]                       axi_out_aw_cache_o ,
    output logic [3:0]                       axi_out_aw_qos_o   ,
    output logic [AXI_ID_WIDTH-1:0]          axi_out_aw_id_o    ,
    output logic [AXI_USER_WIDTH-1:0]        axi_out_aw_user_o  ,
    input  logic                             axi_out_aw_ready_i ,

    // WRITE DATA CHANNEL
    output logic                             axi_out_w_valid_o,
    output logic [AXI_DATA_WIDTH-1:0]        axi_out_w_data_o ,
    output logic [AXI_STRB_WIDTH-1:0]        axi_out_w_strb_o ,
    output logic [AXI_USER_WIDTH-1:0]        axi_out_w_user_o ,
    output logic                             axi_out_w_last_o ,
    input  logic                             axi_out_w_ready_i,

    // WRITE RESPONSE CHANNEL
    input  logic                             axi_out_b_valid_i,
    input  logic [1:0]                       axi_out_b_resp_i ,
    input  logic [AXI_ID_WIDTH-1:0]          axi_out_b_id_i   ,
    input  logic [AXI_USER_WIDTH-1:0]        axi_out_b_user_i ,
    output logic                             axi_out_b_ready_o
);

    enum {IDLE_STATE, WAIT_B_RESP, ERROR_W_STATE, ERROR_B_STATE} CS, NS;
    localparam ID_CHECK_SIZE = 2**AXI_LOOK_BITS;

    logic [NBR_RANGE-1:0]    s_is_in_range;
    logic                    s_is_error_in, s_is_error_out;

    logic                    s_push_to_fifo, s_pop_fifo;
    logic                    s_fifo_is_full;
    logic                    s_fifo_is_empty;

    logic [AXI_ID_WIDTH-1:0]   s_error_id;
    logic [AXI_USER_WIDTH-1:0] s_error_user;

    logic [ID_CHECK_SIZE-1:0]  r_inflight_id, s_inflight_id;
    logic                      s_id_used;

    generate
        for (genvar i=0; i<NBR_RANGE; i++) begin
            assign s_is_in_range[i] = (axi_in_aw_addr_i >= START_ADDR[i]) && (axi_in_aw_addr_i <= STOP_ADDR[i]);
        end
    endgenerate

    assign s_is_error_in = |s_is_in_range;

    assign s_id_used = r_inflight_id[axi_in_aw_id_i[AXI_LOOK_BITS-1:0]];

    always_comb begin : comb_id_used
        s_inflight_id = r_inflight_id;
        if(s_push_to_fifo) begin
            s_inflight_id[axi_in_aw_id_i[AXI_LOOK_BITS-1:0]] = 1'b1;
        end

        if (s_pop_fifo) begin
            s_inflight_id[axi_in_b_id_o[AXI_LOOK_BITS-1:0]] = 1'b0;
        end
    end

    // If the access is valid and in range, store info when acknoledge by the out interface
    // If the access is valid and out of range, directly acknowledge and store the info
    // If the fifo is full, wait until a spot is available to acknowledge a new request
    always_comb begin : comb_aw_channel
        s_push_to_fifo     = 1'b0;
        axi_in_aw_ready_o  = 1'b0;
        axi_out_aw_valid_o = 1'b0;
        if(axi_in_aw_valid_i && !s_fifo_is_full) begin
            if(s_is_error_in)begin
                axi_in_aw_ready_o = 1'b1;
                s_push_to_fifo    = 1'b1;
            end else begin
                axi_out_aw_valid_o = 1'b1;
                axi_in_aw_ready_o  = axi_out_aw_ready_i;//axi_out_aw_valid_o;
                s_push_to_fifo     = axi_out_aw_ready_i;//axi_out_aw_valid_o;
            end
        end
    end

    always_comb begin : comb_next_fsm_state
        NS = CS;

        axi_in_w_ready_o  = 1'b0;
        axi_in_b_valid_o  = 1'b0;
        axi_in_b_resp_o   = axi_out_b_resp_i;
        axi_in_b_id_o     = axi_out_b_id_i;
        axi_in_b_user_o   = axi_out_b_user_i;

        axi_out_w_valid_o  = 1'b0;

        axi_out_b_ready_o = axi_in_b_ready_i;

        s_pop_fifo        = 1'b0;
        case(CS)

        IDLE_STATE :
        begin
            if(!s_fifo_is_empty)begin
                if(s_is_error_out)begin
                    NS = ERROR_W_STATE;
                end else begin
                    axi_out_w_valid_o = axi_in_w_valid_i;
                    axi_in_w_ready_o  = axi_out_w_ready_i;
                    if (axi_in_w_last_i && axi_in_w_valid_i && axi_out_w_ready_i) begin
                        if(axi_out_b_valid_i && axi_in_b_ready_i)begin
                            s_pop_fifo = 1'b1;
                        end else begin
                            NS = WAIT_B_RESP;
                        end
                    end
                end
            end
        end

        WAIT_B_RESP:
        begin
            axi_in_b_valid_o = axi_out_b_valid_i;
            if(axi_out_b_valid_i && axi_in_b_ready_i)begin
                s_pop_fifo = 1'b1;
                NS = IDLE_STATE;
            end
        end

        ERROR_W_STATE:
        begin
            axi_in_w_ready_o = 1'b1;
            if(axi_in_w_valid_i && axi_in_w_last_i) begin
                NS = ERROR_B_STATE;
            end
        end

        ERROR_B_STATE:
        begin
            axi_in_b_valid_o = 1'b1;
            axi_in_b_resp_o  = 2'b10;
            axi_in_b_id_o    = s_error_id;

            axi_out_b_ready_o = 1'b0;
            axi_in_b_user_o   = s_error_user;
            if(axi_in_b_ready_i)begin
                NS = IDLE_STATE;
                s_pop_fifo = 1'b1;
            end
        end

        endcase
    end

    always_ff @( posedge i_clk, negedge i_rst_n ) begin : ff_fsm
        if(!i_rst_n) begin
            CS <= IDLE_STATE;
            r_inflight_id <= '0;
        end else begin
            CS <= NS;
            r_inflight_id <= s_inflight_id;
        end
    end

    fifo_v3 #(
        .FALL_THROUGH (1'b0),
        .DATA_WIDTH   (1+AXI_ID_WIDTH+AXI_USER_WIDTH), //is_error + id + user
        .DEPTH        (NBR_OUTSTANDING_REQ)
    ) write_info_fifo_i (
        .clk_i      (i_clk  ),
        .rst_ni     (i_rst_n),
        .flush_i    ('0     ),
        .unpush_i   ('0     ),
        .testmode_i (i_scan_ckgt_enable),
        // status flags
        .full_o     (s_fifo_is_full),
        .empty_o    (s_fifo_is_empty),
        .usage_o    (),
        // as long as the queue is not full we can push new data
        .data_i     ({s_is_error_in, axi_in_aw_id_i, axi_in_aw_user_i}),
        .push_i     (s_push_to_fifo),
        // as long as the queue is not empty we can pop new elements
        .data_o     ({s_is_error_out, s_error_id, s_error_user}),
        .pop_i      (s_pop_fifo)
    );
    //Passthrough signals
    assign axi_out_aw_addr_o   = axi_in_aw_addr_i  ;
    assign axi_out_aw_prot_o   = axi_in_aw_prot_i  ;
    assign axi_out_aw_region_o = axi_in_aw_region_i;
    assign axi_out_aw_len_o    = axi_in_aw_len_i   ;
    assign axi_out_aw_size_o   = axi_in_aw_size_i  ;
    assign axi_out_aw_atop_o   = axi_in_aw_atop_i  ;
    assign axi_out_aw_burst_o  = axi_in_aw_burst_i ;
    assign axi_out_aw_lock_o   = axi_in_aw_lock_i  ;
    assign axi_out_aw_cache_o  = axi_in_aw_cache_i ;
    assign axi_out_aw_qos_o    = axi_in_aw_qos_i   ;
    assign axi_out_aw_id_o     = axi_in_aw_id_i    ;
    assign axi_out_aw_user_o   = axi_in_aw_user_i  ;

    // WRITE DATA CHANNEL
    assign axi_out_w_data_o  = axi_in_w_data_i ;
    assign axi_out_w_strb_o  = axi_in_w_strb_i ;
    assign axi_out_w_user_o  = axi_in_w_user_i ;
    assign axi_out_w_last_o  = axi_in_w_last_i ;

endmodule
