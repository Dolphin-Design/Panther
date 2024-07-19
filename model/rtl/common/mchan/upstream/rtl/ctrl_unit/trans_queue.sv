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

import mchan_pkg::*;

module trans_queue
#(
  parameter int TRANS_QUEUE_WIDTH     = 10,
  parameter int TRANS_QUEUE_DEPTH     = 2,
  parameter int TCDM_ADD_WIDTH        = 16,
  parameter int EXT_ADD_WIDTH         = 16,
  parameter int MCHAN_LEN_WIDTH       = 16,
  parameter int LOG_TRANS_QUEUE_DEPTH = (TRANS_QUEUE_DEPTH == 1) ? 1 : $clog2(TRANS_QUEUE_DEPTH)
)
(
  input  logic                         clk_i,
  input  logic                         rst_ni,
  
  input  logic                         req_i,
  output logic                         gnt_o,
  input  logic [TRANS_QUEUE_WIDTH-1:0] dat_i,
  
  output logic                         tx_req_o,
  input  logic                         tx_gnt_i,
  output logic [TRANS_QUEUE_WIDTH-1:0] tx_dat_o,
  
  output logic                         rx_req_o,
  input  logic                         rx_gnt_i,
  output logic [TRANS_QUEUE_WIDTH-1:0] rx_dat_o
);
 
  // Internal data structures
  logic [LOG_TRANS_QUEUE_DEPTH-1:0]                        s_pointer_in;     // location to which we last wrote
  logic [LOG_TRANS_QUEUE_DEPTH-1:0]                        s_pointer_in_tx;  // location to which we last wrote tx table
  logic [LOG_TRANS_QUEUE_DEPTH-1:0]                        s_pointer_in_rx;  // location to which we last wrote rx table
  logic [LOG_TRANS_QUEUE_DEPTH-1:0]                        s_pointer_out_tx; // location from which we last sent tx table
  logic [LOG_TRANS_QUEUE_DEPTH-1:0]                        s_pointer_out_rx; // location from which we last sent rx queue
  logic [TRANS_QUEUE_DEPTH-1:0][LOG_TRANS_QUEUE_DEPTH-1:0] s_table_tx;       // tx table to point to the actual buffer location
  logic [TRANS_QUEUE_DEPTH-1:0][LOG_TRANS_QUEUE_DEPTH-1:0] s_table_rx;       // rx table to point to the actual buffer location
  logic [TRANS_QUEUE_DEPTH-1:0]                            s_busy;           // busy tag
  logic [LOG_TRANS_QUEUE_DEPTH:0]                          s_elements;       // number of elements in the buffer
  logic [LOG_TRANS_QUEUE_DEPTH:0]                          s_tx_elements;    // number of tx elements in the buffer
  logic [LOG_TRANS_QUEUE_DEPTH:0]                          s_rx_elements;    // number of rx elements in the buffer
  logic [TRANS_QUEUE_DEPTH-1:0][TRANS_QUEUE_WIDTH-1:0]     s_buffer;
  logic                                                    s_full;
  logic                                                    s_push;
  logic                                                    s_pop_tx;
  logic                                                    s_pop_rx;
  
  integer                                                  s_loop1;
  integer                                                  s_loop2;
  integer                                                  s_loop3;      
  
  assign s_full = (s_elements == TRANS_QUEUE_DEPTH);
  
  assign s_push   = req_i && !s_full;
  assign s_pop_tx = tx_gnt_i && tx_req_o;
  assign s_pop_rx = rx_gnt_i && rx_req_o;
   
  // COMPUTE NUMBER OF ELEMENTS IN THE TRANS QUEUE
  always_ff @(posedge clk_i or negedge rst_ni) begin : p_elements_sequential
    if (rst_ni == 1'b0) begin
      s_elements    <= 0;
      s_tx_elements <= 0;
      s_rx_elements <= 0;
    end else begin
      case ({s_push,s_pop_tx,s_pop_rx})
        
        3'b000:
          begin
            s_elements    <= s_elements;
            s_tx_elements <= s_tx_elements;
            s_rx_elements <= s_rx_elements;
          end
        
        3'b001:
          begin
            s_elements    <= s_elements - 1;
            s_tx_elements <= s_tx_elements;
            s_rx_elements <= s_rx_elements - 1;
          end
        
        3'b010:
          begin
            s_elements    <= s_elements - 1;
            s_tx_elements <= s_tx_elements - 1;
            s_rx_elements <= s_rx_elements;
          end
        
        3'b011:
          begin
            s_elements    <= s_elements - 2;
            s_tx_elements <= s_tx_elements - 1;
            s_rx_elements <= s_rx_elements - 1;
          end
        
        3'b100:
          begin
            s_elements <= s_elements + 1;
            if (dat_i[MCHAN_LEN_WIDTH + TCDM_ADD_WIDTH + EXT_ADD_WIDTH] == 1'b0) begin // TX PUSH OPERATION
                s_tx_elements <= s_tx_elements + 1;
                s_rx_elements <= s_rx_elements;
            end else begin // RX PUSH OPERATION
              s_tx_elements <= s_tx_elements;
              s_rx_elements <= s_rx_elements + 1;
            end
          end
              
          3'b101:
            begin
              s_elements <= s_elements;
              if (dat_i[MCHAN_LEN_WIDTH + TCDM_ADD_WIDTH + EXT_ADD_WIDTH] == 1'b0) begin // TX PUSH OPERATION
                s_tx_elements <= s_tx_elements + 1;
                s_rx_elements <= s_rx_elements - 1;
              end else begin // RX PUSH OPERATION
                s_tx_elements <= s_tx_elements;
                s_rx_elements <= s_rx_elements;
              end
            end
          
          3'b110:
            begin
              s_elements <= s_elements;
              if (dat_i[MCHAN_LEN_WIDTH + TCDM_ADD_WIDTH + EXT_ADD_WIDTH] == 1'b0) begin // TX PUSH OPERATION
                s_tx_elements <= s_tx_elements;
                s_rx_elements <= s_rx_elements;
              end else begin // RX PUSH OPERATION
                s_tx_elements <= s_tx_elements - 1;
                s_rx_elements <= s_rx_elements + 1;
              end
            end
          
          3'b111:
            begin
              s_elements <= s_elements - 1;
              if (dat_i[MCHAN_LEN_WIDTH + TCDM_ADD_WIDTH + EXT_ADD_WIDTH] == 1'b0) begin // TX PUSH OPERATION
                s_tx_elements <= s_tx_elements;
                s_rx_elements <= s_rx_elements - 1;
              end else begin // RX PUSH OPERATION
                s_tx_elements <= s_tx_elements - 1;
                s_rx_elements <= s_rx_elements;
              end
            end
        
      endcase
    end
  end
   
  // COMPUTE CURRENT POINTER_IN LOCATION
  always_comb begin : p_compute_pointer
    s_pointer_in = 0;
    for (s_loop1 = TRANS_QUEUE_DEPTH - 1 ; s_loop1 >= 0  ; s_loop1 = s_loop1 - 1) begin
      if (s_busy[s_loop1] == 1'b0) begin
        s_pointer_in = s_loop1;
      end
    end
  end
  
  // WRITE TRANS QUEUE
  always_ff @(posedge clk_i or negedge rst_ni) begin : p_write
    if (rst_ni == 1'b0) begin
      for (s_loop2 = 0 ; s_loop2 < TRANS_QUEUE_DEPTH ; s_loop2 = s_loop2 + 1) begin
        s_buffer[s_loop2] <= 0;
      end
    end else begin
      if (req_i && !s_full) begin
        s_buffer[s_pointer_in] <= dat_i;
      end
    end
  end
  
  // UPDATE POINTERS
  always_ff @(posedge clk_i or negedge rst_ni) begin : p_update_pointer
    if (rst_ni == 1'b0) begin
      s_pointer_in_rx  <= 0;
      s_pointer_in_tx  <= 0;
      s_pointer_out_rx <= 0;
      s_pointer_out_tx <= 0;
      s_busy           <= 0;
      for (s_loop3 = 0 ; s_loop3 < TRANS_QUEUE_DEPTH ; s_loop3 = s_loop3 + 1) begin
        s_table_tx[s_loop3] <= 0;
        s_table_rx[s_loop3] <= 0;
      end
    end else begin
      if (req_i && !s_full) begin
        if (dat_i[MCHAN_LEN_WIDTH + TCDM_ADD_WIDTH + EXT_ADD_WIDTH] == 1'b0) begin // TX OPERATION
          s_table_tx[s_pointer_in_tx] <= s_pointer_in;
          s_busy[s_pointer_in] <= 1;
          if (s_pointer_in_tx == $unsigned(TRANS_QUEUE_DEPTH - 1)) begin
            s_pointer_in_tx <= 0;
          end else begin
             s_pointer_in_tx <= s_pointer_in_tx + 1;
          end
        end else begin // RX OPERATION
          s_table_rx[s_pointer_in_rx] <= s_pointer_in;
          s_busy[s_pointer_in] <= 1;
          if (s_pointer_in_rx == $unsigned(TRANS_QUEUE_DEPTH - 1)) begin
            s_pointer_in_rx <= 0;
          end else begin
            s_pointer_in_rx <= s_pointer_in_rx + 1;
          end
        end
      end
         
      if (tx_gnt_i && tx_req_o) begin
        s_busy[s_table_tx[s_pointer_out_tx]] <= 0;
        if (s_pointer_out_tx == $unsigned(TRANS_QUEUE_DEPTH-1)) begin //unreachable LINT
          s_pointer_out_tx <= 0;
        end else begin
          s_pointer_out_tx <= s_pointer_out_tx + 1;
        end
      end
       
      if (rx_gnt_i && rx_req_o) begin
        s_busy[s_table_rx[s_pointer_out_rx]] <= 0;
        if (s_pointer_out_rx == $unsigned(TRANS_QUEUE_DEPTH-1)) begin //unreachable LINT
          s_pointer_out_rx <= 0;
        end else begin
          s_pointer_out_rx <= s_pointer_out_rx + 1;
        end 
      end
           
    end
  end

   
  // UPDATE OUTPUT PORTS
  assign tx_dat_o  = s_buffer[s_table_tx[s_pointer_out_tx]];
  assign rx_dat_o  = s_buffer[s_table_rx[s_pointer_out_rx]];
  
  assign tx_req_o = (s_tx_elements != 0);
  assign rx_req_o = (s_rx_elements != 0);
  
  assign gnt_o = ~s_full;
   
endmodule
