// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

import event_unit_pkg::*;

module hw_mutex_unit
#(
  parameter int NB_CORES = 4,
  parameter int MUTEX_MSG_W = 32
)
(
  // clock and reset
  input  logic clk_i,
  input  logic rst_ni,

  // lock and unlock req from each core
  input  logic [NB_CORES-1:0] lock_req_i,
  input  logic [NB_CORES-1:0] unlock_req_i,

  // read and write data for messaging after wakeup
  input  logic [MUTEX_MSG_W-1:0] mutex_msg_wdata_i,
  output logic [MUTEX_MSG_W-1:0] mutex_msg_rdata_o,

  // event output to flag assignment of mutex to a specific core
  output logic [NB_CORES-1:0] mutex_event_o

);

  // registers
  logic [MUTEX_MSG_W-1:0]      mutex_msg_DP;
  logic [MUTEX_MSG_W-1:0]      mutex_msg_DN;
  logic [NB_CORES-1:0]         req_mask_DP;
  logic [NB_CORES-1:0]         req_mask_DN;
  logic [$clog2(NB_CORES)-1:0] req_core_DP;
  logic [$clog2(NB_CORES)-1:0] req_core_DN;

  // internal signals
  logic [NB_CORES-1:0]         req_mask_clr;
  logic [NB_CORES-1:0]         ff1_idx_onehot;
  logic [NB_CORES-1:0]         ff1_inp;
  logic [$clog2(NB_CORES)-1:0] ff1_idx_bin;

  logic event_out_mask;

  enum logic { UNLOCKED, LOCKED } mutex_CS, mutex_NS;


  assign mutex_msg_rdata_o = mutex_msg_DP;
  assign mutex_event_o     = (event_out_mask) ? ff1_idx_onehot : '0;

  assign mutex_msg_DN   = (|unlock_req_i) ? mutex_msg_wdata_i : mutex_msg_DP;
  assign req_mask_DN    = ( req_mask_DP | lock_req_i ) & ~req_mask_clr;
  
  assign ff1_idx_onehot = (1'b1 << ff1_idx_bin);
  assign ff1_inp        = req_mask_DP | lock_req_i;

  // FSM to control the state of the mutex (locked/unlocked)
  always_comb begin : p_mutex_fsm
    mutex_NS       = mutex_CS;
    req_core_DN    = req_core_DP;

    event_out_mask = 1'b0;
    req_mask_clr   = '0;

    case (mutex_CS)
      UNLOCKED: begin
        // if at least one core requests the mutex, flag assigment to core selected by ff1
        if ( |lock_req_i ) begin
          req_mask_clr   = ff1_idx_onehot;
          event_out_mask = 1'b1;
          req_core_DN    = ff1_idx_bin;
          mutex_NS       = LOCKED;
        end
      end
      LOCKED: begin
        // check if mutex is getting unlocked
        if ( |unlock_req_i ) begin
          // check if another core is waiting
          if ( |req_mask_DP | (|lock_req_i) ) begin
            req_mask_clr   = ff1_idx_onehot;
            event_out_mask = 1'b1;
            req_core_DN    = ff1_idx_bin;
          end
          else begin
            mutex_NS = UNLOCKED;
          end
        end
      end
      default:
        begin
          mutex_NS = UNLOCKED;
        end
    endcase // mutex_CS
  end



  // instantiation of find-first-1 (find-first-set) block
  ff1_loop #(
    .WIDTH(NB_CORES) )
  ff1_loop_i (
    .vector_i(ff1_inp),
    .idx_bin_o(ff1_idx_bin),
    .no1_o()
  );

  always_ff @(posedge clk_i, negedge rst_ni) begin
    if ( rst_ni == 1'b0 ) begin
      mutex_CS     <= UNLOCKED;
      mutex_msg_DP <= '0;
      req_mask_DP  <= '0;
      req_core_DP  <= '0;
    end
    else begin
      mutex_CS     <= mutex_NS;
      mutex_msg_DP <= mutex_msg_DN;
      req_mask_DP  <= req_mask_DN; 
      req_core_DP  <= req_core_DN;
    end
  end

endmodule // hw_mutex_unit
