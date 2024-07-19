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

module axi2mem_rd_channel
#(
    // PARAMETERS
    parameter PER_ADDR_WIDTH = 32,
    parameter PER_ID_WIDTH   = 5,
    parameter AXI_ADDR_WIDTH = 32,
    parameter AXI_DATA_WIDTH = 64,
    parameter AXI_USER_WIDTH = 6,
    parameter AXI_ID_WIDTH   = 3
)
(
    input  logic                           clk_i,
    input  logic                           rst_ni,
    input  logic                           test_en_i,

    // AXI4 MASTER
    //***************************************
    // READ ADDRESS CHANNEL
    input  logic                           axi_slave_ar_valid_i,
    input  logic [AXI_ADDR_WIDTH-1:0]      axi_slave_ar_addr_i,
    input  logic [2:0]                     axi_slave_ar_prot_i,
    input  logic [3:0]                     axi_slave_ar_region_i,
    input  logic [7:0]                     axi_slave_ar_len_i,
    input  logic [2:0]                     axi_slave_ar_size_i,
    input  logic [1:0]                     axi_slave_ar_burst_i,
    input  logic                           axi_slave_ar_lock_i,
    input  logic [3:0]                     axi_slave_ar_cache_i,
    input  logic [3:0]                     axi_slave_ar_qos_i,
    input  logic [AXI_ID_WIDTH-1:0]        axi_slave_ar_id_i,
    input  logic [AXI_USER_WIDTH-1:0]      axi_slave_ar_user_i,
    output logic                           axi_slave_ar_ready_o,

    // READ DATA CHANNEL
    output logic                           axi_slave_r_valid_o,
    output logic [AXI_DATA_WIDTH-1:0]      axi_slave_r_data_o,
    output logic [1:0]                     axi_slave_r_resp_o,
    output logic                           axi_slave_r_last_o,
    output logic [AXI_ID_WIDTH-1:0]        axi_slave_r_id_o,
    output logic [AXI_USER_WIDTH-1:0]      axi_slave_r_user_o,
    input  logic                           axi_slave_r_ready_i,

    // CONTROL SIGNALS
    output logic [1:0][5:0]                trans_id_o,
    output logic [1:0][31:0]               trans_add_o,
    output logic [1:0][3:0]                trans_be_o,  //Byte enable is used for test and set, to avoid curruption of neighboor locations
    output logic [1:0]                     trans_req_o,
    output logic [1:0]                     trans_last_o,
    input  logic [1:0]                     trans_gnt_i,

    // Data Signals
    input  logic [63:0]                    data_dat_i,
    input  logic [5:0]                     data_id_i,
    input  logic                           data_last_i,
    output logic                           data_req_o,
    input  logic                           data_gnt_i
);

    enum logic [1:0] { TRANS_IDLE, TRANS_RUN, TRANS_ERROR, TRANS_STALLED } CS, NS;

    logic [7:0]                             s_axi_slave_ar_len;
    logic [AXI_ADDR_WIDTH-1:0]              s_axi_slave_ar_addr;
    logic [AXI_ID_WIDTH-1:0]                s_axi_slave_ar_id;
    logic [2:0]                             s_axi_slave_ar_size;


    logic                                   s_start_count;
    logic [12:0]                            s_trans_count;
    logic [31:0]                            s_trans_addr;
    logic                                   s_trans_complete;

    logic                                   s_ready_id;
    logic                                   s_axi_slave_ar_full;

    logic [7:0]                             burst_cnt_r, burst_cnt_s;
    logic                                   update_busrt_cnt_s;

    logic                                   w_empty;

    //**********************************************************
    //********************* REQUEST CHANNEL ********************
    //**********************************************************

    //SAMPLES THE NUMBER OF TRANSACTIONS AND THE ADDRESS
    always_ff @ (posedge clk_i, negedge rst_ni)
    begin
        if (rst_ni == 1'b0)
        begin
            s_axi_slave_ar_len  <= '0;
            s_axi_slave_ar_addr <= '0;
            s_axi_slave_ar_size <= '0;
        end
        else
        begin
            if ( axi_slave_ar_valid_i == 1'b1 && axi_slave_ar_ready_o == 1'b1 )
            begin
                if (axi_slave_ar_size_i == 3'h0) begin
                   s_axi_slave_ar_addr <= axi_slave_ar_addr_i[AXI_ADDR_WIDTH-1:0];
                end 
                else if (axi_slave_ar_size_i == 3'h1) begin
                   s_axi_slave_ar_addr <= {axi_slave_ar_addr_i[AXI_ADDR_WIDTH-1:1],1'b0};
                end 
                else if (axi_slave_ar_size_i == 3'h2) begin
                   s_axi_slave_ar_addr <= {axi_slave_ar_addr_i[AXI_ADDR_WIDTH-1:2],2'b00};
                end 
                else begin
                   s_axi_slave_ar_addr <= {axi_slave_ar_addr_i[AXI_ADDR_WIDTH-1:3],3'b000};
                end
                s_axi_slave_ar_len  <= axi_slave_ar_len_i;
                s_axi_slave_ar_size <= axi_slave_ar_size_i;
            end
        end
    end

    //COUNTER FOR NUMBER OF CELLS
    always_ff @ (posedge clk_i, negedge rst_ni)
    begin
        if(rst_ni == 1'b0) begin
            s_trans_count <= '0;
        end
        else
        if ( trans_req_o == 2'b11 && trans_gnt_i == 2'b11 && s_start_count == 1'b1 ) begin
            s_trans_count <= '0;
        end
        else
        if ( trans_req_o == 2'b11 && trans_gnt_i == 2'b11 ) begin
            s_trans_count <= s_trans_count+1;
        end
        else begin
            s_trans_count <= s_trans_count;
        end
    end

    always_comb
    begin
        if ( s_trans_count ==  s_axi_slave_ar_len-1 ) begin
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

        axi_slave_ar_ready_o = '0;

        trans_add_o          = '0;
        trans_req_o          = '0;
        trans_last_o         = '0;

        s_start_count        = '0;

        update_busrt_cnt_s   = '0;
        burst_cnt_s          = '0;

        trans_be_o           = '0;
        
        NS                   = TRANS_IDLE;

        case(CS)

            TRANS_IDLE:
            begin
                if ( axi_slave_ar_valid_i == 1'b1)                        // REQUEST FROM READ ADDRESS CHANNEL
                begin
                    if((axi_slave_ar_burst_i != 2'b01) && (axi_slave_ar_len_i != '0)) //Burst other than incr are not supported when len>1 beat
                    begin
                        if ( !w_empty) begin
                            NS = TRANS_STALLED;
                        end else begin
                            NS = TRANS_ERROR;
                            update_busrt_cnt_s   = 1'b1;
                            burst_cnt_s          = axi_slave_ar_len_i;
                            axi_slave_ar_ready_o = 1'b1;
                        end
                    end else begin
                        if(trans_gnt_i[0] == 1'b1 &&  trans_gnt_i[1] == 1'b1 && // TCDM CMD QUEUE IS AVAILABLE
                        s_ready_id == 1'b1 )
                        begin

                            axi_slave_ar_ready_o = 1'b1;

                            trans_req_o[0] = 1'b1;
                            trans_req_o[1] = 1'b1;

		            if (axi_slave_ar_size_i == 3'h0) begin
                                trans_add_o[0] = axi_slave_ar_addr_i[AXI_ADDR_WIDTH-1:0];
                                trans_add_o[1] = axi_slave_ar_addr_i[AXI_ADDR_WIDTH-1:0];
                                trans_be_o = 8'h11 << trans_add_o[0][1:0];
                            end 
                            else if (axi_slave_ar_size_i == 3'h1) begin
                                trans_add_o[0] = {axi_slave_ar_addr_i[AXI_ADDR_WIDTH-1:1],1'b0};
                                trans_add_o[1] = {axi_slave_ar_addr_i[AXI_ADDR_WIDTH-1:1],1'b0};
                                trans_be_o = 8'h33 << (2 * trans_add_o[0][1]);
                            end 
                            else if (axi_slave_ar_size_i == 3'h2) begin
                                trans_add_o[0] = {axi_slave_ar_addr_i[AXI_ADDR_WIDTH-1:2],2'b00};
                                trans_add_o[1] = {axi_slave_ar_addr_i[AXI_ADDR_WIDTH-1:2],2'b00};
                                trans_be_o = '1;
                            end 
                            else begin
                   		trans_add_o[0] = {axi_slave_ar_addr_i[AXI_ADDR_WIDTH-1:3],3'b000};
                            	trans_add_o[1] = {axi_slave_ar_addr_i[AXI_ADDR_WIDTH-1:3],3'b000} + 4;
                                trans_be_o = '1;
                            end

                            if ( axi_slave_ar_len_i == 1'b0 ) // SINGLE BEAT TRANSACTION
                            begin
                                trans_last_o[0] = 1'b1;
                                trans_last_o[1] = 1'b1;

                                NS = TRANS_IDLE;
                            end
                            else // BURST
                            begin
                                s_start_count = 1'b1;

                                NS = TRANS_RUN;
                            end
                        end
                    end
                end
                else
                begin
                    NS = TRANS_IDLE;
                end
            end

            TRANS_RUN:
            begin
                axi_slave_ar_ready_o = 1'b0;

                if ( trans_gnt_i[0] == 1'b1 && trans_gnt_i[1] == 1'b1 )
                begin

                    trans_req_o[0]       = 1'b1;
                    trans_req_o[1]       = 1'b1;

                    trans_add_o[0] = s_trans_addr;
                    if (s_axi_slave_ar_size != 3'h3) begin
                      trans_add_o[1] = s_trans_addr;
                    end else
                    begin
                      trans_add_o[1] = s_trans_addr + 4;
                    end

                    case(s_axi_slave_ar_size)
                        3'h3: begin // 64 bit transactions
                            trans_be_o = '1;
                        end
                        3'h2: begin // 32 bit transactions
                            trans_be_o = '1;
                        end
                        3'h1: begin // 16 bit transactions
                            trans_be_o = 8'h33 << (2 * trans_add_o[0][1]);
                        end
                        3'h0: begin // 8 bit transactions
                            trans_be_o = 8'h11 << trans_add_o[0][1:0];
                        end
                        default: begin
                        end
                    endcase

                    if ( s_trans_complete == 1'b1 )
                    begin
                        trans_last_o[0] = 1'b1;
                        trans_last_o[1] = 1'b1;
                        NS          = TRANS_STALLED;
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

            TRANS_STALLED:
            begin
                NS = TRANS_STALLED;
                if(w_empty) begin
                   NS = TRANS_IDLE;
                end
            end

            TRANS_ERROR:
            begin
                NS = TRANS_ERROR;
                if(axi_slave_r_ready_i) begin
                    update_busrt_cnt_s = 1'b1;
                    burst_cnt_s = burst_cnt_r - 1;
                    if(burst_cnt_r == '0) begin
                        NS = TRANS_IDLE;
                    end
                end
            end

            default:
            begin
            end

        endcase
    end

    assign s_trans_addr  = s_axi_slave_ar_addr + ( s_trans_count + 1 << (s_axi_slave_ar_size) );

    assign trans_id_o[0] = axi_slave_ar_id_i;
    assign trans_id_o[1] = axi_slave_ar_id_i;

    always_ff @( posedge clk_i , negedge rst_ni ) begin : ff_burst_cnt
        if(rst_ni == '0) begin
            burst_cnt_r <= '0;
        end else if (update_busrt_cnt_s) begin
            burst_cnt_r <= burst_cnt_s;
        end
    end

    //**********************************************************
    //**************** RESPONSE CHANNEL ************************
    //**********************************************************

    always_comb
    begin
        data_req_o          = 1'b0;
        axi_slave_r_valid_o = 1'b0;
        axi_slave_r_last_o  = 1'b0;
        axi_slave_r_data_o  = data_dat_i;
        axi_slave_r_resp_o  = '0;
        if (CS == TRANS_ERROR) begin
            axi_slave_r_valid_o = 1'b1;
            axi_slave_r_resp_o  = 2'b10;
            axi_slave_r_data_o  = 64'hCA11_AB1E_DEAD_BEEF;
            axi_slave_r_last_o  = (burst_cnt_r == '0);
        end else
        if ( data_gnt_i == 1'b1 &&          // DATA IS AVAILABLE ON THE DATA FIFO
        axi_slave_r_ready_i == 1'b1 )  // THE AXI INTERFACE IS ABLE TO ACCETT A DATA

        begin
            if ( data_last_i == 1'b1 ) // LAST BEAT
            begin
                data_req_o          = 1'b1;
                axi_slave_r_valid_o = 1'b1;
                axi_slave_r_last_o  = 1'b1;
            end
            else
            begin
                data_req_o          = 1'b1;
                axi_slave_r_valid_o = 1'b1;
                axi_slave_r_last_o  = 1'b0;
            end
        end
        else
        begin
            data_req_o          = 1'b0;
            axi_slave_r_valid_o = 1'b0;
            axi_slave_r_last_o  = 1'b0;
        end
    end

    //**********************************************************
    //**************** FIFO TO STORE R_ID **********************
    //**********************************************************

    assign s_ready_id = ~s_axi_slave_ar_full;

    fifo_v3 #(
      .FALL_THROUGH ( 1'b0 ),
      .DATA_WIDTH   ( AXI_ID_WIDTH ),
      .DEPTH        ( 4 )
    ) r_id_buf_i (
      .clk_i        ( clk_i ),
      .rst_ni       ( rst_ni ),
      .flush_i      ( 1'b0 ),
      .unpush_i     ( 1'b0 ),
      .testmode_i   ( test_en_i),
      // status flags
      .full_o       ( s_axi_slave_ar_full ),
      .empty_o      ( w_empty ),
      .usage_o      ( /* Not Used */ ),
      // as long as the queue is not full we can push new data
      .data_i       ( axi_slave_ar_id_i ),
      .push_i       ( axi_slave_ar_valid_i == 1'b1 && axi_slave_ar_ready_o == 1'b1 ),
      // as long as the queue is not empty we can pop new elements
      .data_o       ( s_axi_slave_ar_id ),
      .pop_i        ( axi_slave_r_last_o == 1'b1 && axi_slave_r_ready_i == 1'b1 && axi_slave_r_valid_o == 1'b1 )
    );

    assign axi_slave_r_user_o  = '0;
    assign axi_slave_r_id_o    = s_axi_slave_ar_id;

endmodule
