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

module trans_unpack #(
  // OVERRIDDEN FROM TOP
  parameter int TRANS_SID_WIDTH    = 1               ,
  parameter int TCDM_ADD_WIDTH     = 12              ,
  parameter int EXT_ADD_WIDTH      = 29              ,
  parameter int MCHAN_BURST_LENGTH = 64              ,
  // DEFINED IN MCHAN_PKG
  parameter int MCHAN_OPC_WIDTH    = MCHAN_OPC_WIDTH ,
  parameter int MCHAN_LEN_WIDTH    = MCHAN_LEN_WIDTH ,
  parameter int TCDM_OPC_WIDTH     = TCDM_OPC_WIDTH  ,
  parameter int EXT_OPC_WIDTH      = EXT_OPC_WIDTH   ,
  // DERIVED
  parameter int MCHAN_CMD_WIDTH    = MCHAN_LEN_WIDTH   - $clog2(MCHAN_BURST_LENGTH) + 1
)
(
  input  logic                       clk_i              ,
  input  logic                       rst_ni             ,
  input  logic [TRANS_SID_WIDTH-1:0] mchan_sid_i        ,
  input  logic [MCHAN_OPC_WIDTH-1:0] mchan_opc_i        ,
  input  logic [MCHAN_LEN_WIDTH-1:0] mchan_len_i        ,
  input  logic [ TCDM_ADD_WIDTH-1:0] mchan_tcdm_add_i   ,
  input  logic [  EXT_ADD_WIDTH-1:0] mchan_ext_add_i    ,
  input  logic                       mchan_inc_i        ,
  input  logic                       mchan_req_i        ,
  output logic                       mchan_gnt_o        ,
  output logic [MCHAN_CMD_WIDTH-1:0] mchan_cmd_nb_o     ,
  output logic [TRANS_SID_WIDTH-1:0] tcdm_sid_o         ,
  output logic [ TCDM_ADD_WIDTH-1:0] tcdm_add_o         ,
  output logic [ TCDM_OPC_WIDTH-1:0] tcdm_opc_o         ,
  output logic [MCHAN_LEN_WIDTH-1:0] tcdm_len_o         ,
  output logic                       tcdm_req_o         ,
  input  logic                       tcdm_gnt_i         ,
  output logic [TRANS_SID_WIDTH-1:0] ext_sid_o          ,
  output logic [  EXT_ADD_WIDTH-1:0] ext_add_o          ,
  output logic [  EXT_OPC_WIDTH-1:0] ext_opc_o          ,
  output logic [MCHAN_LEN_WIDTH-1:0] ext_len_o          ,
  output logic                       ext_bst_o          ,
  output logic                       ext_req_o          ,
  input  logic                       ext_gnt_i          ,
  output logic [                2:0] trans_tx_ext_add_o ,
  output logic [                2:0] trans_tx_tcdm_add_o,
  output logic [MCHAN_LEN_WIDTH-1:0] trans_tx_len_o     ,
  output logic                       trans_tx_req_o     ,
  input  logic                       trans_tx_gnt_i
);
   
  // MCHAN CMD QUEUE SIGNALS
  logic [TRANS_SID_WIDTH-1:0]        s_mchan_sid_reg;
  logic [MCHAN_OPC_WIDTH-1:0]        s_mchan_opc_reg;
  // FSM SIGNALS
  logic [  EXT_OPC_WIDTH-1:0]        s_mchan_opc         ;
  logic [MCHAN_LEN_WIDTH-1:0]        s_mchan_len         ;
  logic [MCHAN_LEN_WIDTH-1:0]        s_mchan_init_rem_len;
  logic [ TCDM_ADD_WIDTH-1:0]        s_mchan_tcdm_add    ;
  logic [  EXT_ADD_WIDTH-1:0]        s_mchan_ext_add     ;
  logic                              s_mchan_inc         ;
  logic                              s_mchan_req         ;
  logic                              s_mchan_gnt         ;
  logic                              s_ext_add_burst_crossed;
  logic                              s_ext_add_burst_aligned;
  logic [MCHAN_LEN_WIDTH-1:0]        s_mchan_rem_len  ;
  logic [MCHAN_LEN_WIDTH-1:0]        s_mchan_first_len;
  logic [MCHAN_LEN_WIDTH-1:0]        s_mchan_cur_len  ;
  // CMD COUNTER SIGNAS
  logic [MCHAN_CMD_WIDTH-1:0]        s_mchan_cmd_nb    ;
  logic [MCHAN_CMD_WIDTH-1:0]        s_mchan_cmd_nb_reg;
  logic [MCHAN_CMD_WIDTH-1:0]        s_mchan_cmd_count ;
  // TRANSACTION SIGNALS
  logic s_trans_complete;
  
  // FSM STATES SIGNALS
  typedef enum logic { TRANS_IDLE, TRANS_RUN } t_fsm_states;
  t_fsm_states CS, NS;

  //**********************************************************
  //***** COMPUTE NUMBER OF COMMANDS *************************
  //**********************************************************
  
  // CHECKS BURST BOUNDARY CROSSING CONDITION
  always_comb begin : p_burst_crossed
    if ( mchan_ext_add_i[EXT_ADD_WIDTH-1:$clog2(MCHAN_BURST_LENGTH)] != ( ( mchan_ext_add_i + mchan_len_i ) >>  $clog2(MCHAN_BURST_LENGTH) ) ) begin
      s_ext_add_burst_crossed = 1'b1;
    end else begin
      s_ext_add_burst_crossed = 1'b0;
    end
  end
  
  // COMPUTE LENGTH OF FIRST TRANSFER
  always_comb begin : p_compute_len_comb
    if ( s_ext_add_burst_crossed == 1'b0  ) begin
      s_mchan_first_len = mchan_len_i; // BURST BOUNDARY NOT CROSSED
    end else begin
      s_mchan_first_len = MCHAN_BURST_LENGTH - mchan_ext_add_i[$clog2(MCHAN_BURST_LENGTH)-1:0] - 1; // BURST BOUNDARY CROSSED // # OF BYTES -1
    end   
  end
  
  assign s_mchan_init_rem_len = mchan_len_i - s_mchan_first_len; // # OF BYTES
  
  always_comb begin : p_burst_aligned
    if ( s_mchan_init_rem_len[$clog2(MCHAN_BURST_LENGTH)-1:0] == 0 ) begin
      s_ext_add_burst_aligned = 1'b1;
    end else begin
      s_ext_add_burst_aligned = 1'b0;
    end
  end
   
  // COMPUTE NUMBER OF COMMANDS
  always_comb begin : p_compute_cmb_nb
    if ( s_ext_add_burst_crossed == 1'b0 ) begin
      s_mchan_cmd_nb = 0; // # OF CMDS - 1
    end else begin
      if ( s_ext_add_burst_aligned == 1'b1 ) begin
        s_mchan_cmd_nb = s_mchan_init_rem_len >> $clog2(MCHAN_BURST_LENGTH); // # OF CMDS - 1
      end else begin
        s_mchan_cmd_nb = ( s_mchan_init_rem_len >> $clog2(MCHAN_BURST_LENGTH) ) + 1; // # OF CMDS - 1
      end
    end
  end
  
  //**********************************************************
  //***** SAMPLES THE OPCODE OF CURRENT TRANSFER *************
  //**********************************************************
   
  always_ff @ (posedge clk_i, negedge rst_ni) begin : p_sample_opc
    if (rst_ni == 1'b0) begin
      s_mchan_cmd_nb_reg    <= 0;
      s_mchan_opc_reg       <= 0;
      s_mchan_sid_reg       <= 0;
      s_mchan_inc           <= 0;
    end else begin
      if ( mchan_req_i == 1'b1 && mchan_gnt_o == 1'b1 ) begin // SAMPLES DATA AT THE BEGINNING OF EACH MCHAN TRANSFER
        s_mchan_cmd_nb_reg    <= s_mchan_cmd_nb;    // NUMBER OF COMMANDS OF THE CURRENT MCHAN TRANSFER
        s_mchan_opc_reg       <= mchan_opc_i;       // MCHAN OPCODE
        s_mchan_sid_reg       <= mchan_sid_i;       // SID OF CURRENT MCHAN TRANSFER
        s_mchan_inc           <= mchan_inc_i;      // INCREMENTAL TRANSFER
      end
    end
  end
   
  //**********************************************************
  //***** COMPUTES THE LENGTH OF CURRENT TRANSACTION *********
  //**********************************************************
  
  always_ff @ (posedge clk_i, negedge rst_ni) begin : p_compute_len_seq
    if (rst_ni == 1'b0) begin
      s_mchan_cur_len <= '0;  // LENGTH OF CURRENT MCHAN TRANSACTION // OF BYTES - 1
      s_mchan_rem_len <= '0;  // REMAINING LENGHT OF CURRENT MCHAN TRANSFER
    end else begin
      if ( mchan_req_i == 1 && mchan_gnt_o == 1 ) begin // SAMPLES DATA AT THE BEGINNING OF EACH MCHAN TRANSFER
        s_mchan_rem_len <= mchan_len_i;       // # OF BYTES - 1
        s_mchan_cur_len <= s_mchan_first_len; // # OF BYTES - 1
      end else begin
        if ( s_mchan_req == 1'b1 && s_mchan_gnt == 1'b1 ) begin
          s_mchan_rem_len <= s_mchan_rem_len - ( s_mchan_cur_len + 1 ); // # OF BYTES - 1
          if ( s_mchan_rem_len >= MCHAN_BURST_LENGTH-1 ) begin
            s_mchan_cur_len <= MCHAN_BURST_LENGTH-1; // # OF BYTES - 1
          end else begin
            s_mchan_cur_len <= s_mchan_rem_len; // # OF BYTES - 1
          end
        end else begin
          s_mchan_cur_len <= s_mchan_cur_len; // # OF BYTES - 1
          s_mchan_rem_len <= s_mchan_rem_len; // # OF BYTES - 1
        end
      end
    end
  end
   
  //**********************************************************
  //****** COMPUTES THE TCDM ADDRESS OF CURRENT TRANSACTION **
  //**********************************************************
  
  always_ff @ (posedge clk_i, negedge rst_ni) begin : p_compute_tcdm_add
    if (rst_ni == 1'b0) begin
      s_mchan_tcdm_add <= '0;
    end else begin
      if ( mchan_req_i == 1'b1 && mchan_gnt_o == 1'b1 ) begin
        s_mchan_tcdm_add <= mchan_tcdm_add_i;
      end else begin
        if ( s_mchan_req == 1'b1 && s_mchan_gnt == 1'b1 ) begin
          s_mchan_tcdm_add <= s_mchan_tcdm_add + ( s_mchan_cur_len + 1 );
        end else begin
          s_mchan_tcdm_add <= s_mchan_tcdm_add;
        end
      end
    end
  end
   
  //**********************************************************
  //****** COMPUTES THE EXT ADDRESS OF CURRENT TRANSACTION ***
  //**********************************************************
  
  always_ff @ (posedge clk_i, negedge rst_ni) begin : p_compute_ext_add
    if (rst_ni == 1'b0) begin
      s_mchan_ext_add <= 0;
    end else begin
      if ( mchan_req_i == 1'b1 && mchan_gnt_o == 1'b1) begin
        s_mchan_ext_add <= mchan_ext_add_i;
      end else begin
        if ( s_mchan_req == 1'b1 && s_mchan_gnt == 1'b1  && s_mchan_inc == 1'b1 ) begin
          s_mchan_ext_add <= s_mchan_ext_add + ( s_mchan_cur_len + 1 );
        end else begin
          s_mchan_ext_add <= s_mchan_ext_add;
        end
      end
    end
  end
   
  //**********************************************************
  //*********** COUNTER FOR NUMBER OF MCHAN COMMANDS *********
  //**********************************************************
  
  always_ff @ (posedge clk_i, negedge rst_ni) begin : p_cmd_counter
    if(rst_ni == 1'b0) begin
      s_mchan_cmd_count <= 9'b0;
    end else begin
      if ( mchan_req_i == 1'b1 && mchan_gnt_o == 1'b1 ) begin
        s_mchan_cmd_count <= 9'b0;
      end else begin
        if ( s_mchan_req == 1'b1 && s_mchan_gnt == 1'b1 ) begin
          s_mchan_cmd_count <= s_mchan_cmd_count + 1;
        end else begin
          s_mchan_cmd_count <= s_mchan_cmd_count;
        end
      end
    end
  end
  
  always_comb begin : p_trans_complete
    if ( s_mchan_cmd_count == s_mchan_cmd_nb_reg ) begin
      s_trans_complete = 1'b1;
    end else begin
      s_trans_complete = 1'b0;
    end
  end
   
  //**********************************************************
  //********** FINITE STATE MACHINE FOR CMD QUEUE ************
  //**********************************************************
  
  // UPDATE THE STATE
  always_ff @(posedge clk_i, negedge rst_ni) begin : p_update_state
    if(rst_ni == 1'b0) begin
      CS <= TRANS_IDLE;
    end else begin
      CS <= NS;
    end
  end
  
  // COMPUTES NEXT STATE
  always_comb begin : p_compute_state
    mchan_gnt_o = 1;
    s_mchan_req = 0;
    s_mchan_opc = 0;
    s_mchan_len = 0;
    tcdm_sid_o  = 0;
    ext_sid_o   = 0;
    tcdm_add_o  = 0;
    ext_add_o   = 0;
    ext_bst_o   = 0;
   
    case(CS)
      
      TRANS_IDLE:
        begin
          mchan_gnt_o = s_mchan_gnt;
          if ( mchan_req_i == 1'b1 && s_mchan_gnt == 1'b1 ) begin
            NS          = TRANS_RUN;
          end else begin
            NS          = TRANS_IDLE;
          end
        end
      
      TRANS_RUN:
        begin
            mchan_gnt_o = 1'b0;
            s_mchan_opc = s_mchan_opc_reg;
            s_mchan_len = s_mchan_cur_len; // # OF BYTES - 1
            tcdm_sid_o  = s_mchan_sid_reg;
            ext_sid_o   = s_mchan_sid_reg;
            tcdm_add_o  = s_mchan_tcdm_add;
            ext_add_o   = s_mchan_ext_add;
            ext_bst_o   = s_mchan_inc;
           
            if ( s_mchan_gnt == 1'b1 ) begin
              s_mchan_req = 1'b1;
              begin
                if ( s_trans_complete == 1'b1 ) begin
                  s_mchan_len = s_mchan_rem_len; // # OF BYTES - 1
                  NS = TRANS_IDLE;
                end else begin
                  NS = TRANS_RUN;
                end
              end
            end else begin
              NS = TRANS_RUN;
            end
        end
      
      default:
        NS = TRANS_IDLE;
      
    endcase
  end
   
  //**********************************************************
  //********* SPLITS TCDM AND EXT MEMORY REQUESTS ************
  //**********************************************************
  
  assign ext_req_o = s_mchan_req;
  
  always_comb begin : p_tcdm_req
    if ( s_mchan_req == 1'b1 && s_mchan_opc[0] == 1'b0) begin // TX OPERATION. TCDM CMD FOR RX OP IS GENERATED BY EXT INTERFACE
      tcdm_req_o = 1'b1;
    end else begin
      tcdm_req_o = 1'b0;
    end
  end
  
  always_comb begin : p_mchan_gnt
    if ( ( tcdm_gnt_i == 1'b1 && s_mchan_opc[0] == 1'b0 && ext_gnt_i == 1'b1 && trans_tx_gnt_i == 1'b1 ) || // TX OPERATION
        ( s_mchan_opc[0] == 1'b1 && ext_gnt_i == 1'b1 ) ) begin                                             // RX OPERATION
      s_mchan_gnt    = 1'b1;
    end else begin
      s_mchan_gnt    = 1'b0;
    end
  end
   
  //**********************************************************
  //***** TRANSLATES OF MCHAN OPCODES INTO AXI OPCODES *******
  //**********************************************************
  
  always_comb begin : p_translate_opc
    case(s_mchan_opc[0])
     
      MCHAN_OP_TX:
        begin
          tcdm_opc_o[0] = 1'b1; // READ
          ext_opc_o[0]  = 1'b0; // WRITE
        end
      
      MCHAN_OP_RX:
        begin
          tcdm_opc_o[0] = 1'b0; // WRITE
          ext_opc_o[0]  = 1'b1; // READ
        end
      
      default:
        begin
          tcdm_opc_o[0] = 1'b0;
          ext_opc_o[0]  = 1'b0;
        end
     
    endcase
   
    tcdm_len_o = s_mchan_len;  // # OF BYTES - 1
    ext_len_o  = s_mchan_len;  // # OF BYTES - 1
  end
  
  //**********************************************************
  //***** GENERATE SIGNALS FOR TRANSFER UNIT *****************
  //**********************************************************
  
  assign trans_tx_ext_add_o  = ext_add_o[2:0];
  assign trans_tx_tcdm_add_o = tcdm_add_o[2:0];
  assign trans_tx_len_o      = s_mchan_len;              // # OF BYTES - 1
  assign trans_tx_req_o      = ext_req_o && tcdm_req_o;
  assign mchan_cmd_nb_o      = s_mchan_cmd_nb + 1;       // # OF CMDS
   
endmodule
