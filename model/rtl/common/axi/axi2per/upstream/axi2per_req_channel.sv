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

module axi2per_req_channel
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
    input logic                       clk_i,
    input logic                       rst_ni,

    input  logic                      axi_slave_aw_valid_i,
    input  logic [AXI_ADDR_WIDTH-1:0] axi_slave_aw_addr_i,
    input  logic [2:0]                axi_slave_aw_prot_i,
    input  logic [3:0]                axi_slave_aw_region_i,
    input  logic [7:0]                axi_slave_aw_len_i,
    input  logic [2:0]                axi_slave_aw_size_i,
    input  logic [1:0]                axi_slave_aw_burst_i,
    input  logic                      axi_slave_aw_lock_i,
    input  logic [3:0]                axi_slave_aw_cache_i,
    input  logic [3:0]                axi_slave_aw_qos_i,
    input  logic [AXI_ID_WIDTH-1:0]   axi_slave_aw_id_i,
    input  logic [AXI_USER_WIDTH-1:0] axi_slave_aw_user_i,
    output logic                      axi_slave_aw_ready_o,

    // READ ADDRESS CHANNEL
    input  logic                      axi_slave_ar_valid_i,
    input  logic [AXI_ADDR_WIDTH-1:0] axi_slave_ar_addr_i,
    input  logic [2:0]                axi_slave_ar_prot_i,
    input  logic [3:0]                axi_slave_ar_region_i,
    input  logic [7:0]                axi_slave_ar_len_i,
    input  logic [2:0]                axi_slave_ar_size_i,
    input  logic [1:0]                axi_slave_ar_burst_i,
    input  logic                      axi_slave_ar_lock_i,
    input  logic [3:0]                axi_slave_ar_cache_i,
    input  logic [3:0]                axi_slave_ar_qos_i,
    input  logic [AXI_ID_WIDTH-1:0]   axi_slave_ar_id_i,
    input  logic [AXI_USER_WIDTH-1:0] axi_slave_ar_user_i,
    output logic                      axi_slave_ar_ready_o,

    // WRITE DATA CHANNEL
    input  logic                      axi_slave_w_valid_i,
    input  logic [AXI_DATA_WIDTH-1:0] axi_slave_w_data_i,
    input  logic [AXI_STRB_WIDTH-1:0] axi_slave_w_strb_i,
    input  logic [AXI_USER_WIDTH-1:0] axi_slave_w_user_i,
    input  logic                      axi_slave_w_last_i,
    output logic                      axi_slave_w_ready_o,

    // Response channel ready
    input  logic                      axi_slave_b_ready_i,
    input  logic                      axi_slave_r_ready_i,
    // PERIPHERAL REQUEST CHANNEL
    output logic                      per_master_req_o,
    output logic [PER_ADDR_WIDTH-1:0] per_master_add_o,
    output logic                      per_master_we_o,
    output logic [31:0]               per_master_wdata_o,
    output logic [3:0]                per_master_be_o,
    input  logic                      per_master_gnt_i,

    // CONTROL SIGNALS
    output logic                      trans_req_o,
    output logic                      trans_we_o,
    output logic [AXI_ID_WIDTH-1:0]   trans_id_o,
    output logic [AXI_ADDR_WIDTH-1:0] trans_add_o,
    input  logic                      trans_r_valid_i,
    output logic                      trans_b_error_o,
    output logic                      trans_ar_error_o,
    output logic [7:0]                trans_ar_len_o,
    input  logic                      trans_error_done_i,

    // BUSY SIGNAL
    output logic                      busy_o
);

    enum logic [2:0] { TRANS_IDLE, TRANS_WAIT_WRITE_GRANT, TRANS_WAIT_READ_GRANT, TRANS_PENDING, TRANS_ERROR_WRITE, TRANS_WAIT_ERROR_DONE} CS, NS;

    logic [3:0]   s_read_be;
    logic [7:0]   burst_cnt_r, burst_cnt_s;
    logic         update_burst_cnt_s;

    always_comb begin : gen_read_be
        case(axi_slave_ar_addr_i[1:0])
            2'b01   : s_read_be = 4'b1110;
            2'b10   : s_read_be = 4'b1100;
            2'b11   : s_read_be = 4'b1000;
            default : s_read_be = 4'b1111;
        endcase
    end

    always_ff @( posedge clk_i, negedge rst_ni ) begin : blockName
        if(rst_ni == 1'b0) begin
            burst_cnt_r <= '0;
        end else begin
            if(update_burst_cnt_s) begin
                burst_cnt_r <= burst_cnt_s;
            end
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
        axi_slave_ar_ready_o = '0;
        axi_slave_w_ready_o  = '0;

        per_master_req_o     = '0;
        per_master_add_o     = '0;
        per_master_we_o      = '0;
        per_master_wdata_o   = '0;
        per_master_be_o      = '0;

        trans_req_o          = '0;
        trans_we_o           = '0;
        trans_id_o           = '0;
        trans_add_o          = '0;
        trans_ar_error_o     = '0;
        trans_ar_len_o       = '0;

        busy_o               = 1'b1;

        update_burst_cnt_s   = 1'b0;
        trans_b_error_o      = 1'b0;
        burst_cnt_s          = '0;
        NS                   = TRANS_IDLE;

        case(CS)

        TRANS_IDLE:

        begin
            if ( axi_slave_ar_valid_i == 1'b1 && axi_slave_r_ready_i == 1'b1) // REQUEST FROM READ ADDRESS CHANNEL
            begin
                if(axi_slave_ar_len_i != '0) begin
                    NS = TRANS_WAIT_ERROR_DONE;
                    burst_cnt_s = axi_slave_aw_len_i;
                    update_burst_cnt_s = 1'b1;
                    trans_ar_len_o     = axi_slave_ar_len_i;
                    trans_ar_error_o   = 1'b1;
                    trans_we_o         = 1'b1;
                    trans_req_o        = 1'b1;
                    axi_slave_ar_ready_o = 1'b1; // POP DATA FROM THE ADDRESS READ BUFFER
                    trans_id_o           = axi_slave_ar_id_i;
                    trans_add_o          = axi_slave_ar_addr_i;
                end else begin
                    per_master_req_o = 1'b1;                     // MAKE THE REQUEST TO THE PHERIPHERAL INTERCONNECT
                    per_master_we_o  = 1'b1;                     // READ OPERATION
                    per_master_add_o = axi_slave_ar_addr_i;      // ADDRESS COMES FROM ADDRESS READ CHANNEL
                    per_master_be_o  = s_read_be;
                    if ( per_master_gnt_i == 1'b1 ) // THE REQUEST IS ACKNOWLEDGED FROM THE PERIPHERAL INTERCONNECT
                    begin
                        axi_slave_ar_ready_o = 1'b1; // POP DATA FROM THE ADDRESS READ BUFFER

                        trans_req_o          = 1'b1;                // NOTIFY THE RESPONSE CHANNEL THAT THERE IS A PENDING REQUEST
                        trans_we_o           = 1'b1;                // NOTIFY THE RESPONSE CHANNEL THE TYPE OF THE PENDING REQUEST
                        trans_id_o           = axi_slave_ar_id_i;   // NOTIFY THE RESPONSE CHANNEL THE ID OF THE PENDING REQUEST
                        trans_add_o          = axi_slave_ar_addr_i; // NOTIFY THE RESPONSE CHANNEL THE ADDRESS OF THE PENDING REQUEST

                        NS                   = TRANS_PENDING;
                    end else begin
                        NS = TRANS_WAIT_READ_GRANT;
                    end
                end
            end
            else
            begin
                if ( axi_slave_aw_valid_i == 1'b1 && // REQUEST FROM WRITE ADDRESS CHANNEL
                axi_slave_w_valid_i == 1'b1 && axi_slave_b_ready_i == 1'b1)   // REQUEST FROM WRITE DATA CHANNEL
                begin
                    if(axi_slave_aw_len_i != '0) begin
                        NS = TRANS_ERROR_WRITE;
                        burst_cnt_s = axi_slave_aw_len_i;
                        update_burst_cnt_s   = 1'b1;
                        axi_slave_aw_ready_o = 1'b1;

                        trans_req_o          = 1'b1;                // NOTIFY THE RESPONSE CHANNEL THAT THERE IS A PENDING REQUEST
                        trans_we_o           = 1'b0;                // NOTIFY THE RESPONSE CHANNEL THE TYPE OF THE PENDING REQUEST
                        trans_id_o           = axi_slave_aw_id_i;   // NOTIFY THE RESPONSE CHANNEL THE ID OF THE PENDING REQUEST
                        trans_add_o          = axi_slave_aw_addr_i; // NOTIFY THE RESPONSE CHANNEL THE ADDRESS OF THE PENDING REQUEST
                    end else begin
                        per_master_req_o = 1'b1;                     // MAKE THE REQUEST TO THE PHERIPHERAL INTERCONNECT
                        per_master_we_o  = 1'b0;                     // WRITE OPERATION
                        per_master_add_o = axi_slave_aw_addr_i;      // ADDRESS COMES FROM WRITE ADDRESS CHANNEL

                        if ( axi_slave_aw_addr_i[2] == 1'b0 ) // FORWARD THE RIGHT AXI DATA TO THE PERIPHERAL BYTE ENABLE
                        begin
                            per_master_wdata_o  = axi_slave_w_data_i[31:0];
                        end
                        else
                        begin
                            per_master_wdata_o  = axi_slave_w_data_i[63:32];
                        end

                        if ( axi_slave_aw_addr_i[2] == 1'b0 ) // FORWARD THE RIGHT AXI STROBE TO THE PERIPHERAL BYTE ENABLE
                        begin
                            per_master_be_o  = axi_slave_w_strb_i[3:0];
                        end
                        else
                        begin
                            per_master_be_o  = axi_slave_w_strb_i[7:4];
                        end

                        if ( per_master_gnt_i == 1'b1 ) // THE REQUEST IS ACKNOWLEDGED FROM THE PERIPHERAL INTERCONNECT
                        begin
                            axi_slave_aw_ready_o = 1'b1; // POP DATA FROM THE WRITE ADDRESS BUFFER
                            axi_slave_w_ready_o  = 1'b1; // POP DATA FROM THE WRITE DATA BUFFER

                            trans_req_o          = 1'b1;                // NOTIFY THE RESPONSE CHANNEL THAT THERE IS A PENDING REQUEST
                            trans_we_o           = 1'b0;                // NOTIFY THE RESPONSE CHANNEL THE TYPE OF THE PENDING REQUEST
                            trans_id_o           = axi_slave_aw_id_i;   // NOTIFY THE RESPONSE CHANNEL THE ID OF THE PENDING REQUEST
                            trans_add_o          = axi_slave_aw_addr_i; // NOTIFY THE RESPONSE CHANNEL THE ADDRESS OF THE PENDING REQUEST

                            NS                   = TRANS_PENDING;
                        end else begin
                            NS = TRANS_WAIT_WRITE_GRANT;
                        end
                    end
                end else begin
                    busy_o = 1'b0;
                end
            end
        end

        TRANS_WAIT_WRITE_GRANT:
        begin
            per_master_req_o = 1'b1;                     // MAKE THE REQUEST TO THE PHERIPHERAL INTERCONNECT
            per_master_we_o  = 1'b0;                     // WRITE OPERATION
            per_master_add_o = axi_slave_aw_addr_i;      // ADDRESS COMES FROM WRITE ADDRESS CHANNEL

            if ( axi_slave_aw_addr_i[2] == 1'b0 ) // FORWARD THE RIGHT AXI DATA TO THE PERIPHERAL BYTE ENABLE
            begin
                per_master_wdata_o  = axi_slave_w_data_i[31:0];
            end
            else
            begin
                per_master_wdata_o  = axi_slave_w_data_i[63:32];
            end

            if ( axi_slave_aw_addr_i[2] == 1'b0 ) // FORWARD THE RIGHT AXI STROBE TO THE PERIPHERAL BYTE ENABLE
            begin
                per_master_be_o  = axi_slave_w_strb_i[3:0];
            end
            else
            begin
                per_master_be_o  = axi_slave_w_strb_i[7:4];
            end

            if (per_master_gnt_i == 1'b1) begin
                axi_slave_aw_ready_o = 1'b1; // POP DATA FROM THE WRITE ADDRESS BUFFER
                axi_slave_w_ready_o  = 1'b1; // POP DATA FROM THE WRITE DATA BUFFER

                trans_req_o          = 1'b1;                // NOTIFY THE RESPONSE CHANNEL THAT THERE IS A PENDING REQUEST
                trans_we_o           = 1'b0;                // NOTIFY THE RESPONSE CHANNEL THE TYPE OF THE PENDING REQUEST
                trans_id_o           = axi_slave_aw_id_i;   // NOTIFY THE RESPONSE CHANNEL THE ID OF THE PENDING REQUEST
                trans_add_o          = axi_slave_aw_addr_i; // NOTIFY THE RESPONSE CHANNEL THE ADDRESS OF THE PENDING REQUEST
                NS = TRANS_PENDING;
            end else begin
                NS = TRANS_WAIT_WRITE_GRANT;
            end
        end

        TRANS_WAIT_READ_GRANT:
        begin
            per_master_req_o = 1'b1;                     // MAKE THE REQUEST TO THE PHERIPHERAL INTERCONNECT
            per_master_we_o  = 1'b1;                     // READ OPERATION
            per_master_add_o = axi_slave_ar_addr_i;      // ADDRESS COMES FROM ADDRESS READ CHANNEL
            per_master_be_o  = s_read_be;
            if (per_master_gnt_i == 1'b1) begin
                axi_slave_ar_ready_o = 1'b1; // POP DATA FROM THE ADDRESS READ BUFFER

                trans_req_o          = 1'b1;                // NOTIFY THE RESPONSE CHANNEL THAT THERE IS A PENDING REQUEST
                trans_we_o           = 1'b1;                // NOTIFY THE RESPONSE CHANNEL THE TYPE OF THE PENDING REQUEST
                trans_id_o           = axi_slave_ar_id_i;   // NOTIFY THE RESPONSE CHANNEL THE ID OF THE PENDING REQUEST
                trans_add_o          = axi_slave_ar_addr_i; // NOTIFY THE RESPONSE CHANNEL THE ADDRESS OF THE PENDING REQUEST
                NS = TRANS_PENDING;
            end else begin
                NS = TRANS_WAIT_READ_GRANT;
            end
        end

        TRANS_PENDING:

        begin
            axi_slave_aw_ready_o = '0;     // PENDING TRANSACTION WRITE ADDRESS CHANNEL NOT READY
            axi_slave_ar_ready_o = '0;     // PENDING TRANSACTION READ ADDRESS CHANNEL NOT READY
            axi_slave_w_ready_o  = '0;     // PENDING TRANSACTION WRITE DATA CHANNEL NOT READY

            // busy_o               = '1;

            if ( trans_r_valid_i == 1'b1 ) // RECEIVED NOTIFICATION FROM RESPONSE CHANNEL: TRANSACTION COMPLETED
            begin
                NS = TRANS_IDLE;
            end
            else
            begin
                NS = TRANS_PENDING;
            end
        end

        TRANS_ERROR_WRITE:
        begin
            NS = TRANS_ERROR_WRITE;
            // busy_o               = 1'b1;
            axi_slave_w_ready_o  = 1'b1;
            if(axi_slave_w_valid_i) begin
                if (axi_slave_w_last_i == 1'b1) begin
                    NS = TRANS_WAIT_ERROR_DONE;
                    trans_b_error_o = 1'b1;
                end
            end
        end

        TRANS_WAIT_ERROR_DONE:
        begin
            if(trans_error_done_i) begin
                NS = TRANS_IDLE;
            end else begin
                NS = TRANS_WAIT_ERROR_DONE;
                // busy_o = 1'b1;
            end
        end
    endcase
end

   // UNUSED SIGNALS
   //axi_slave_aw_prot_i
   //axi_slave_aw_region_i
   //axi_slave_aw_len_i
   //axi_slave_aw_lock_i
   //axi_slave_aw_cache_i
   //axi_slave_aw_qos_i
   //axi_slave_aw_user_i

   //axi_slave_ar_prot_i
   //axi_slave_ar_region_i
   //axi_slave_ar_len_i
   //axi_slave_ar_lock_i
   //axi_slave_ar_cache_i
   //axi_slave_ar_qos_i
   //axi_slave_ar_user_i

   //axi_slave_w_user_i

endmodule
