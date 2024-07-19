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

//==============================================================================
//
//      Function: Wrapper for T-Head fpu div sqrt unit
//
//==============================================================================

module fp_iter_divsqrt_th_32_wrapper_2_STAGE
#(
  parameter ID_WIDTH        = 9,
  parameter NB_ARGS         = 2,
  parameter DATA_WIDTH      = 32,
  parameter OPCODE_WIDTH    = 1,
  parameter FLAGS_IN_WIDTH  = 3,
  parameter FLAGS_OUT_WIDTH = 5
)
(
   // Clock and Reset
   input  logic                               clk,
   input  logic                               rst_n,

   // APU Side: Master port
   input  logic                               apu_req_i,
   output logic                               apu_gnt_o,
   input  logic [ID_WIDTH-1:0]                apu_ID_i,

   // request channel
   input  logic [NB_ARGS-1:0][DATA_WIDTH-1:0] apu_operands_i,
   input  logic [OPCODE_WIDTH-1:0]            apu_op_i,
   input  logic [FLAGS_IN_WIDTH-1:0]          apu_flags_i,

   // response channel
   input  logic                               apu_rready_i, // not used
   output logic                               apu_rvalid_o,
   output logic [DATA_WIDTH-1:0]              apu_rdata_o,
   output logic [FLAGS_OUT_WIDTH-1:0]         apu_rflags_o,
   output logic [ID_WIDTH-1:0]                apu_rID_o
);

   logic                 div_start;
   logic                 sqrt_start;
   logic [NB_ARGS-1:0][DATA_WIDTH-1:0]   apu_operands_Q;
   logic [OPCODE_WIDTH-1:0]              apu_op_Q;
   logic [FLAGS_IN_WIDTH-1:0]            apu_flags_Q;
   logic                                 sample_data;
   logic                                 apu_gnt_int;

   logic [1:0]                           apu_rvalid_pipe_Q;
   logic [1:0][DATA_WIDTH-1:0]           apu_rdata_pipe_Q;
   logic [1:0][FLAGS_OUT_WIDTH-1:0]      apu_rflags_pipe_Q;
   logic [1:0][ID_WIDTH-1:0]             apu_rID_pipe_Q;

   logic                             apu_rvalid_int;
   logic [63:0]                      apu_rdata_int;
   logic [FLAGS_OUT_WIDTH-1:0]       apu_rflags_int;
   logic [ID_WIDTH-1:0]              apu_rID_int;

   logic                             unit_ready_d;


   enum logic [1:0] { IDLE, RUNNING , INIT_FPU } CS, NS;
   logic div_op, sqrt_op;        // input signalling with unit
   logic op_starting;            // high in the cycle a new operation starts

   // Operations are gated by the FSM ready. Invalid input ops run a sqrt to not lose illegal instr.

  // -----------------
  // DIVSQRT instance
  // -----------------
  // thead define fdsu module's input and output
  //Calling th_int all signal used only for connecting th modules
  logic        ctrl_fdsu_ex1_sel;
  logic        th_int_fdsu_fpu_ex1_cmplt;
  logic  [4:0] th_int_fdsu_fpu_ex1_fflags;
  logic  [7:0] th_int_fdsu_fpu_ex1_special_sel;
  logic  [3:0] th_int_fdsu_fpu_ex1_special_sign;
  logic        fdsu_fpu_no_op;  // Unused in CV32 fpu
  logic  [2:0] idu_fpu_ex1_eu_sel;
  logic [31:0] th_int_fdsu_frbus_data;
  logic  [4:0] th_int_fdsu_frbus_fflags;
  logic        th_int_fdsu_frbus_wb_vld;

  logic fdsu_fpu_ex1_stall;
  // dp
  logic [31:0] th_int_dp_frbus_ex2_data;
  logic  [4:0] th_int_dp_frbus_ex2_fflags;
  logic  [2:0] th_int_dp_xx_ex1_cnan;
  logic  [2:0] th_int_dp_xx_ex1_id;
  logic  [2:0] th_int_dp_xx_ex1_inf;
  logic  [2:0] th_int_dp_xx_ex1_norm;  // Unused in CV32 fpu
  logic  [2:0] th_int_dp_xx_ex1_qnan;
  logic  [2:0] th_int_dp_xx_ex1_snan;
  logic  [2:0] th_int_dp_xx_ex1_zero;
  logic        ex2_inst_wb;
  logic        ex2_inst_wb_vld_d, ex2_inst_wb_vld_q;

  // frbus
  logic [31:0] fpu_idu_fwd_data;
  logic  [4:0] fpu_idu_fwd_fflags;
  logic        fpu_idu_fwd_vld;


  assign ex2_inst_wb_vld_d = ctrl_fdsu_ex1_sel;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ex2_inst_wb_vld_q <= '0;
    end else begin
      ex2_inst_wb_vld_q <= ex2_inst_wb_vld_d;
    end
  end

pa_fdsu_top i_divsqrt_thead (
   .cp0_fpu_icg_en                ( 1'b0               ),  // input clock gate enable in gated_clk_cell, active 0.
   .cp0_fpu_xx_dqnan              ( 1'b0               ),  // When dqnan = 0, QNAN (0x7fc00000).
   .cp0_yy_clk_en                 ( 1'b1               ),  // clock enable in gated_clk_cell, active 1.
   .cpurst_b                      ( rst_n              ),  // If negedge cpu reset, all state machines reset to IDLE.
   .ctrl_fdsu_ex1_sel             ( ctrl_fdsu_ex1_sel  ),  // select operands
   .ctrl_xx_ex1_cmplt_dp          ( ctrl_fdsu_ex1_sel  ),  // complete datapath
   .ctrl_xx_ex1_inst_vld          ( ctrl_fdsu_ex1_sel  ),  // instance valid
   .ctrl_xx_ex1_stall             ( fdsu_fpu_ex1_stall ),
   .ctrl_xx_ex1_warm_up           ( 1'b0                             ),
   .ctrl_xx_ex2_warm_up           ( 1'b0                             ),
   .ctrl_xx_ex3_warm_up           ( 1'b0                             ),
   .dp_xx_ex1_cnan                ( th_int_dp_xx_ex1_cnan            ),  // Special input type determination
   .dp_xx_ex1_id                  ( th_int_dp_xx_ex1_id              ),
   .dp_xx_ex1_inf                 ( th_int_dp_xx_ex1_inf             ),
   .dp_xx_ex1_qnan                ( th_int_dp_xx_ex1_qnan            ),
   .dp_xx_ex1_rm                  ( apu_flags_Q[2:0]                 ),  // rounding mode
   .dp_xx_ex1_snan                ( th_int_dp_xx_ex1_snan            ),
   .dp_xx_ex1_zero                ( th_int_dp_xx_ex1_zero            ),
   .fdsu_fpu_debug_info           (                                  ),  // output, not used
   .fdsu_fpu_ex1_cmplt            ( th_int_fdsu_fpu_ex1_cmplt        ),  // output, ctrl_xx_ex1_cmplt_dp && idu_fpu_ex1_eu_sel_i[2]
   .fdsu_fpu_ex1_cmplt_dp         (                                  ),  // output, not used
   .fdsu_fpu_ex1_fflags           ( th_int_fdsu_fpu_ex1_fflags       ),  // output, special case fflags
   .fdsu_fpu_ex1_special_sel      ( th_int_fdsu_fpu_ex1_special_sel  ),  // output, special case type selection
   .fdsu_fpu_ex1_special_sign     ( th_int_fdsu_fpu_ex1_special_sign ),  // output, special case sign determination
   .fdsu_fpu_ex1_stall            ( fdsu_fpu_ex1_stall        ),  // output, determine whether stall in ex1
   .fdsu_fpu_no_op                ( fdsu_fpu_no_op            ),  // output, if Write Back SM and fdsu SM no operation, fdsu_fpu_no_op = 1; Otherwise if busy, fdsu_fpu_no_op = 0. (not used)
   .fdsu_frbus_data               ( th_int_fdsu_frbus_data           ),  // output, normal case result
   .fdsu_frbus_fflags             ( th_int_fdsu_frbus_fflags         ),  // output, normal case fflags
   .fdsu_frbus_freg               (                                  ),  // output, determined by input idu_fpu_ex1_dst_freg
   .fdsu_frbus_wb_vld             ( th_int_fdsu_frbus_wb_vld         ),  // output, determine whether write back valid
   .forever_cpuclk                ( clk                              ),
   .frbus_fdsu_wb_grant           ( th_int_fdsu_frbus_wb_vld         ),  // input is fdsu_frbus_wb_vld
   .idu_fpu_ex1_dst_freg          ( 5'h0f                     ),  // register index to write back (not used)
   .idu_fpu_ex1_eu_sel            ( idu_fpu_ex1_eu_sel        ),  // time to select operands
   .idu_fpu_ex1_func              ( {8'b0, div_start , sqrt_start} ),
   .idu_fpu_ex1_srcf0             ( apu_operands_Q[0][31:0]        ),  // the first operand
   .idu_fpu_ex1_srcf1             ( apu_operands_Q[1][31:0]        ),  // the second operand
   .pad_yy_icg_scan_en            ( 1'b0                           ),  // input of core_top, set to 1'b0 from the beginning to end
   .rtu_xx_ex1_cancel             ( 1'b0                           ),
   .rtu_xx_ex2_cancel             ( 1'b0                           ),
   .rtu_yy_xx_async_flush         ( 1'b0                           ),  // YPR: AFAIK corresponds to Kill_SI, not used in PANTHER
   .rtu_yy_xx_flush               ( 1'b0                           )
  );

  pa_fpu_dp  x_pa_fpu_dp (
    .cp0_fpu_icg_en              ( 1'b0                             ),
    .cp0_fpu_xx_rm               ( apu_flags_Q[2:0]                 ),  // Rounding mode
    .cp0_yy_clk_en               ( 1'b1                             ),
    .ctrl_xx_ex1_inst_vld        ( ctrl_fdsu_ex1_sel                ),
    .ctrl_xx_ex1_stall           ( 1'b0                             ),
    .ctrl_xx_ex1_warm_up         ( 1'b0                             ),
    .dp_frbus_ex2_data           ( th_int_dp_frbus_ex2_data         ),  // output
    .dp_frbus_ex2_fflags         ( th_int_dp_frbus_ex2_fflags       ),  // output
    .dp_xx_ex1_cnan              ( th_int_dp_xx_ex1_cnan            ),  // output
    .dp_xx_ex1_id                ( th_int_dp_xx_ex1_id              ),  // output
    .dp_xx_ex1_inf               ( th_int_dp_xx_ex1_inf             ),  // output
    .dp_xx_ex1_norm              ( th_int_dp_xx_ex1_norm            ),  // output
    .dp_xx_ex1_qnan              ( th_int_dp_xx_ex1_qnan            ),  // output
    .dp_xx_ex1_snan              ( th_int_dp_xx_ex1_snan            ),  // output
    .dp_xx_ex1_zero              ( th_int_dp_xx_ex1_zero            ),  // output
    .ex2_inst_wb                 ( ex2_inst_wb                      ),  // output
    .fdsu_fpu_ex1_fflags         ( th_int_fdsu_fpu_ex1_fflags       ),
    .fdsu_fpu_ex1_special_sel    ( th_int_fdsu_fpu_ex1_special_sel  ),
    .fdsu_fpu_ex1_special_sign   ( th_int_fdsu_fpu_ex1_special_sign ),
    .forever_cpuclk              ( clk                              ),
    .idu_fpu_ex1_eu_sel          ( idu_fpu_ex1_eu_sel               ),
    .idu_fpu_ex1_func            ( {8'b0, div_start, sqrt_start}    ),
    .idu_fpu_ex1_gateclk_vld     ( th_int_fdsu_fpu_ex1_cmplt        ),
    .idu_fpu_ex1_rm              ( apu_flags_Q[2:0]                 ),  // Rounding mode
    .idu_fpu_ex1_srcf0           ( apu_operands_Q[0][31:0]          ),
    .idu_fpu_ex1_srcf1           ( apu_operands_Q[1][31:0]          ),
    .idu_fpu_ex1_srcf2           ( '0                               ),
    .pad_yy_icg_scan_en          ( 1'b0                             )
  );

  // Select output between fdsu and fpu
  pa_fpu_frbus x_pa_fpu_frbus (
    .ctrl_frbus_ex2_wb_req     ( ex2_inst_wb & ex2_inst_wb_vld_q ),
    .dp_frbus_ex2_data         ( th_int_dp_frbus_ex2_data        ),
    .dp_frbus_ex2_fflags       ( th_int_dp_frbus_ex2_fflags      ),
    .fdsu_frbus_data           ( th_int_fdsu_frbus_data          ),
    .fdsu_frbus_fflags         ( th_int_fdsu_frbus_fflags        ),
    .fdsu_frbus_wb_vld         ( th_int_fdsu_frbus_wb_vld        ),
    .fpu_idu_fwd_data          ( fpu_idu_fwd_data                ),  // output
    .fpu_idu_fwd_fflags        ( fpu_idu_fwd_fflags              ),  // output
    .fpu_idu_fwd_vld           ( fpu_idu_fwd_vld                 )   // output
  );

   always_comb begin
      apu_rdata_int       = fpu_idu_fwd_data[31:0];
      apu_rflags_int[4:0] = fpu_idu_fwd_fflags[4:0];
      apu_rvalid_int      = fpu_idu_fwd_vld;
   end

   assign apu_rvalid_o = apu_rvalid_pipe_Q[1];
   assign apu_rdata_o  = apu_rdata_pipe_Q [1];
   assign apu_rflags_o = apu_rflags_pipe_Q[1];
   assign apu_rID_o    = apu_rID_pipe_Q   [1];


   always_ff @(posedge clk or negedge rst_n)
   begin
         if(~rst_n)
         begin
            apu_rID_int        <= '0;
            apu_operands_Q     <= '0;
            apu_op_Q           <= '0;
            apu_flags_Q        <= '0;
            CS                 <= IDLE;
            apu_rvalid_pipe_Q  <= '0;
            apu_rdata_pipe_Q   <= '0;
            apu_rflags_pipe_Q  <= '0;
            apu_rID_pipe_Q     <= '0;
         end
         else
         begin
            CS <= NS;
            if(sample_data)
            begin
               apu_rID_int     <= apu_ID_i;
               apu_operands_Q  <= apu_operands_i;
               apu_op_Q        <= apu_op_i;
               apu_flags_Q     <= apu_flags_i;
            end

            apu_rvalid_pipe_Q[0] <= apu_rvalid_int;
            apu_rdata_pipe_Q [0] <= apu_rdata_int[DATA_WIDTH-1:0];
            apu_rflags_pipe_Q[0] <= apu_rflags_int;
            apu_rID_pipe_Q   [0] <= apu_rID_int;

            apu_rvalid_pipe_Q[1] <= apu_rvalid_pipe_Q[0];
            apu_rdata_pipe_Q [1] <= apu_rdata_pipe_Q [0];
            apu_rflags_pipe_Q[1] <= apu_rflags_pipe_Q[0];
            apu_rID_pipe_Q   [1] <= apu_rID_pipe_Q   [0];
         end

   end

  // apu_gnt_int related to state machine, different under special and normal cases.
  always_comb begin
    if(op_starting && apu_gnt_int) begin
      if(ex2_inst_wb && ex2_inst_wb_vld_q) begin
        unit_ready_d = 1'b1;
      end else begin
        unit_ready_d = 1'b0;
      end
    end else if(apu_rvalid_int) begin
      unit_ready_d = 1'b1;
    end else begin
      unit_ready_d = apu_gnt_int;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      apu_gnt_int <= 1'b1;
    end else begin
      apu_gnt_int <= unit_ready_d;
    end
  end

   always_comb
   begin
      NS = CS;
      apu_gnt_o   = 1'b0;
      sample_data = 1'b0;
      div_start   = 1'b0;
      sqrt_start  = 1'b0;
      op_starting = 1'b0;

      ctrl_fdsu_ex1_sel = 1'b0;
      idu_fpu_ex1_eu_sel = 3'h0; // time to select operands, only idu_fpu_ex1_eu_sel_i[2] works in fdsu module
      case(CS)
        IDLE:
        begin
          apu_gnt_o   = apu_gnt_int;
          sample_data = apu_req_i;

          if(apu_req_i & apu_gnt_o )
            NS = INIT_FPU;

        end

        // YPR : Used to cut path from the core ?
        INIT_FPU:
        begin
          div_start  = ~apu_op_Q[0];
          sqrt_start =  apu_op_Q[0];
          op_starting = 1'b1;
          ctrl_fdsu_ex1_sel = 1'b1; // time to select operands
          idu_fpu_ex1_eu_sel = 3'h4; // time to select operands, only idu_fpu_ex1_eu_sel_i[2] works in fdsu module
          //If stall in ex1, we should keep sending operands
          if(fdsu_fpu_ex1_stall) begin
            NS = INIT_FPU;
          end else begin
            NS = RUNNING;
          end
        end

        RUNNING:
        begin
          apu_gnt_o = 1'b0;

          if(apu_rvalid_o)
            NS = IDLE;
        end

        default:
        begin
          NS = IDLE;
        end
      endcase // CS
   end

endmodule
