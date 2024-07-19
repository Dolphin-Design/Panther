// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License. You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

// Davide Rossi <davide.rossi@unibo.it>

module axi2mem_wr_channel
#(
    // PARAMETERS
    parameter PER_ADDR_WIDTH = 32,
    parameter PER_ID_WIDTH   = 5,
    parameter AXI_ADDR_WIDTH = 32,
    parameter AXI_DATA_WIDTH = 64,
    parameter AXI_USER_WIDTH = 6,
    parameter AXI_ID_WIDTH   = 3,
    // LOCAL PARAMETERS --> DO NOT OVERRIDE
    parameter AXI_STRB_WIDTH = AXI_DATA_WIDTH/8 // DO NOT OVERRIDE
)
(
    input logic                            clk_i,
    input logic                            rst_ni,
    input logic                            test_en_i,

    input  logic                           axi_slave_aw_valid_i,
    input  logic [AXI_ADDR_WIDTH-1:0]      axi_slave_aw_addr_i,
    input  logic [2:0]                     axi_slave_aw_prot_i,
    input  logic [3:0]                     axi_slave_aw_region_i,
    input  logic [7:0]                     axi_slave_aw_len_i,
    input  logic [2:0]                     axi_slave_aw_size_i,
    input  logic [1:0]                     axi_slave_aw_burst_i,
    input  logic                           axi_slave_aw_lock_i,
    input  logic [3:0]                     axi_slave_aw_cache_i,
    input  logic [3:0]                     axi_slave_aw_qos_i,
    input  logic [AXI_ID_WIDTH-1:0]        axi_slave_aw_id_i,
    input  logic [AXI_USER_WIDTH-1:0]      axi_slave_aw_user_i,
    output logic                           axi_slave_aw_ready_o,

    // WRITE DATA CHANNEL
    input  logic                           axi_slave_w_valid_i,
    input  logic [AXI_DATA_WIDTH-1:0]      axi_slave_w_data_i,
    input  logic [AXI_STRB_WIDTH-1:0]      axi_slave_w_strb_i,
    input  logic [AXI_USER_WIDTH-1:0]      axi_slave_w_user_i,
    input  logic                           axi_slave_w_last_i,
    output logic                           axi_slave_w_ready_o,

    // WRITE RESPONSE CHANNEL
    output logic                           axi_slave_b_valid_o,
    output logic [1:0]                     axi_slave_b_resp_o,
    output logic [AXI_ID_WIDTH-1:0]        axi_slave_b_id_o,
    output logic [AXI_USER_WIDTH-1:0]      axi_slave_b_user_o,
    input  logic                           axi_slave_b_ready_i,

    // CONTROL SIGNALS
    output logic [1:0][5:0]                trans_id_o,
    output logic [1:0][31:0]               trans_add_o,
    output logic [1:0]                     trans_last_o,
    output logic [1:0]                     trans_req_o,
    input  logic [1:0]                     trans_gnt_i,

    output logic                           trans_r_gnt_o,
    input  logic [5:0]                     trans_r_id_i,
    input  logic                           trans_r_req_i,

    // DATA SIGNALS
    output logic [63:0]                    data_dat_o,
    output logic [7:0]                     data_strb_o,
    output logic                           data_req_o,
    input  logic                           data_gnt_i
);

    enum logic [1:0] { TRANS_IDLE, TRANS_RUN, TRANS_ERROR, TRANS_ERROR_B } CS, NS;

    logic [7:0]                        s_axi_slave_aw_len;
    logic [AXI_ADDR_WIDTH-1:0]         s_axi_slave_aw_addr;
    logic [2:0]                        s_axi_slave_aw_size;
    logic                              s_start_count;
    logic [12:0]                       s_trans_count;
    logic [12:0]                       s_trans_count_del;
    logic [31:0]                       s_trans_addr;
    logic [31:0]                       s_trans_addr_pre;
    logic                              s_trans_complete;

    logic [AXI_ID_WIDTH:0]             s_axi_slave_b_id; // id + one bit for error
    logic                              s_is_error;

    logic                              s_ready_id;
    logic                              s_axi_slave_aw_full;
    logic                              s_resp_fifo_empty;

    logic [7:0]                             burst_cnt_r, burst_cnt_s;
    logic                                   update_busrt_cnt_s;

    //**********************************************************
    //********************* REQUEST CHANNEL ********************
    //**********************************************************

    //SAMPLES THE NUMBER OF TRANSACTIONS AND THE ADDRESS
    always_ff @ (posedge clk_i, negedge rst_ni)
    begin
        if (rst_ni == 1'b0)
        begin
            s_axi_slave_aw_len  <= '0;
            s_axi_slave_aw_addr <= '0;
            s_axi_slave_aw_size <= '0;
        end
        else
        begin
            if (axi_slave_aw_valid_i == 1'b1 && axi_slave_aw_ready_o == 1'b1) begin
                if (axi_slave_aw_size_i == 3'h0) begin
                   s_axi_slave_aw_addr <= axi_slave_aw_addr_i[AXI_ADDR_WIDTH-1:0];
                end
                else if (axi_slave_aw_size_i == 3'h1) begin
                   s_axi_slave_aw_addr <= {axi_slave_aw_addr_i[AXI_ADDR_WIDTH-1:1],1'b0};
                end
                else if (axi_slave_aw_size_i == 3'h2) begin
                   s_axi_slave_aw_addr <= {axi_slave_aw_addr_i[AXI_ADDR_WIDTH-1:2],2'b00};
                end
                else begin
                   s_axi_slave_aw_addr <= {axi_slave_aw_addr_i[AXI_ADDR_WIDTH-1:3],3'b000};
                end
                s_axi_slave_aw_len  <= axi_slave_aw_len_i;
                s_axi_slave_aw_size <= axi_slave_aw_size_i;
            end
        end
    end

    //COUNTER FOR NUMBER OF CELLS
    always_ff @ (posedge clk_i, negedge rst_ni)
    begin
        if(rst_ni == 1'b0) begin
            s_trans_count <= '0;
            s_trans_count_del <= '0;
        end else begin
            if ( trans_req_o == 2'b11 && trans_gnt_i == 2'b11 && s_start_count == 1'b1 ) begin
                s_trans_count <= '0;
            end else begin
                if ( trans_req_o == 2'b11 && trans_gnt_i == 2'b11 ) begin
                    s_trans_count <= s_trans_count+1;
                end else begin
                    s_trans_count <= s_trans_count;
                end
            end
            s_trans_count_del <= s_trans_count;
        end
    end

    always_comb
    begin
        if ( s_trans_count ==  s_axi_slave_aw_len-1 ) begin
        s_trans_complete = 1'b1;
        end else begin
            s_trans_complete = 1'b0;
        end
    end

    // UPDATE THE STATE
    always_ff @(posedge clk_i, negedge rst_ni)
    begin
        if(rst_ni == 1'b0)
        begin
            CS <= TRANS_IDLE;
        end
        else
        begin
            CS <= NS;
        end
    end

    // COMPUTE NEXT STATE
    always_comb
    begin

        axi_slave_aw_ready_o = '0;

        trans_add_o          = '0;
        trans_req_o          = '0;
        trans_last_o         = '0;

        data_req_o           = '0;

        s_start_count        = '0;
        burst_cnt_s          = '0;
        update_busrt_cnt_s   = '0;

        s_is_error           = 1'b0;

        NS                   = TRANS_IDLE;

        case(CS)

        TRANS_IDLE:
        begin
            if ( axi_slave_aw_valid_i == 1'b1 &&                      // REQUEST FROM WRITE ADDRESS CHANNEL
            axi_slave_w_valid_i == 1'b1) begin
                if((axi_slave_aw_burst_i != 2'b01)&&(axi_slave_aw_len_i != '0)) begin //Only INCR burst supported when len>1 beat
                    s_is_error           = 1'b1;
                    if(s_resp_fifo_empty) begin  //when req would result in error, we need to wait until all previous request are done
                        if(axi_slave_w_last_i == 1'b1) begin
                            NS = TRANS_ERROR_B;
                        end
                        else begin
                            NS = TRANS_ERROR;
                        end

                        axi_slave_aw_ready_o = 1'b1;
                        update_busrt_cnt_s   = 1'b1;
                        burst_cnt_s          = s_axi_slave_aw_len;
                    end
                end else begin                      // REQUEST FROM WRITE DATA CHANNEL
                    if (trans_gnt_i[0] == 1'b1 &&  trans_gnt_i[1] == 1'b1 && // TCDM CMD QUEUE IS AVAILABLE
                    s_ready_id == 1'b1 )                                 // THE ID FIFO CAN ACCEPT NEW ID
                    begin
                        axi_slave_aw_ready_o = 1'b1;

                        trans_req_o[0] = 1'b1;
                        trans_req_o[1] = 1'b1;

                        trans_add_o[0] = {axi_slave_aw_addr_i[AXI_ADDR_WIDTH-1:3],3'b000};
                        trans_add_o[1] = {axi_slave_aw_addr_i[AXI_ADDR_WIDTH-1:3],3'b000} + 4;

                        data_req_o     = 1'b1;

                        if ( axi_slave_aw_len_i == 1'b0 ) // SINGLE BEAT TRANSACTION
                        begin
                            trans_last_o[0] = 1'b1;
                            trans_last_o[1] = 1'b1;

                            NS              = TRANS_IDLE;
                        end
                        else // BURST
                        begin
                            s_start_count = 1'b1;

                            NS            = TRANS_RUN;
                        end
                    end
                end
            end
            else
            begin
                NS          = TRANS_IDLE;
            end
        end

        TRANS_RUN:
        begin
            axi_slave_aw_ready_o = 1'b0;

            if ( axi_slave_w_valid_i == 1'b1 &&                     // REQUEST FROM WRITE DATA CHANNEL
            trans_gnt_i[0] == 1'b1 && trans_gnt_i[1] == 1'b1 ) // TCDM CMD QUEUEs ARE AVAILABLE
            begin

                trans_req_o[0] = 1'b1;
                trans_req_o[1] = 1'b1;

                trans_add_o[0] = s_trans_addr;
                if (s_axi_slave_aw_size != 3'h3) begin
                  trans_add_o[1] = s_trans_addr;
                end else
                begin
                  trans_add_o[1] = s_trans_addr + 4;
                end

                data_req_o     = 1'b1;

                if ( s_trans_complete == 1'b1 )
                begin
                    trans_last_o[0] = 1'b1;
                    trans_last_o[1] = 1'b1;

                    NS = TRANS_IDLE;
                end
                else
                begin
                    NS = TRANS_RUN;
                end
            end
            else
            begin
                NS = TRANS_RUN;
            end
        end

        TRANS_ERROR:
        begin
            NS = TRANS_ERROR;
            if(axi_slave_w_valid_i == 1'b1) begin

                // burst_cnt_s = burst_cnt_r - 1;
                // update_busrt_cnt_s = 1'b1;

                if(axi_slave_w_last_i == 1'b1) begin
                    NS = TRANS_ERROR_B;
                end
            end
        end

        TRANS_ERROR_B:
        begin
            if(axi_slave_b_ready_i == 1'b1) begin
                NS = TRANS_IDLE;
            end else begin
                NS = TRANS_ERROR_B;
            end
        end

        default:
        begin
        end

        endcase

    end

    always_ff @( posedge clk_i , negedge rst_ni ) begin : ff_burst_cnt
        if(rst_ni == '0) begin
            burst_cnt_r <= '0;
        end else if (update_busrt_cnt_s) begin
            burst_cnt_r <= burst_cnt_s;
        end
    end

    assign s_trans_addr  = s_axi_slave_aw_addr + ( ( s_trans_count + 1 )  << (s_axi_slave_aw_size) );


    assign trans_id_o[0] = axi_slave_aw_id_i;
    assign trans_id_o[1] = axi_slave_aw_id_i;

    assign data_dat_o    = axi_slave_w_data_i;
    assign data_strb_o   = axi_slave_w_strb_i;

    assign axi_slave_w_ready_o = ((data_gnt_i && (CS != TRANS_ERROR_B)) || (CS == TRANS_ERROR)) && (!s_axi_slave_aw_full || CS == TRANS_RUN) && !s_is_error;

    //**********************************************************
    //**************** RESPONSE CHANNEL ************************
    //**********************************************************

    //**********************************************************
    //**************** FIFO TO STORE R_ID **********************
    //**********************************************************

    assign s_ready_id = ~s_axi_slave_aw_full;

    fifo_v3 #(
      .FALL_THROUGH ( 1'b0 ),
      .DATA_WIDTH   ( AXI_ID_WIDTH+1 ),
      .DEPTH        ( 4 )
    ) r_id_buf_i (
      .clk_i        ( clk_i ),
      .rst_ni       ( rst_ni ),
      .flush_i      ( 1'b0 ),
      .unpush_i     ( 1'b0 ),
      .testmode_i   ( test_en_i ),
      // status flags
      .full_o       ( s_axi_slave_aw_full ),
      .empty_o      ( s_resp_fifo_empty   ),
      .usage_o      ( /* Not Used */ ),
      // as long as the queue is not full we can push new data
      .data_i       ( {s_is_error, axi_slave_aw_id_i} ),
      .push_i       ( axi_slave_aw_valid_i == 1'b1 && axi_slave_aw_ready_o == 1'b1 ),
      // as long as the queue is not empty we can pop new elements
      .data_o       ( s_axi_slave_b_id ),
      .pop_i        ( axi_slave_b_valid_o == 1'b1 && axi_slave_b_ready_i == 1'b1 )
    );


    assign axi_slave_b_valid_o = trans_r_req_i || (CS == TRANS_ERROR_B);
    assign axi_slave_b_resp_o  = (s_axi_slave_b_id[AXI_ID_WIDTH] == 1'b1) ? 2'b10 : '0;//(CS == TRANS_ERROR_B) ? 2'b10 : '0;
    assign axi_slave_b_id_o    = s_axi_slave_b_id[AXI_ID_WIDTH-1:0];
    assign axi_slave_b_user_o  = '0;

    assign trans_r_gnt_o       = axi_slave_b_ready_i;

endmodule
