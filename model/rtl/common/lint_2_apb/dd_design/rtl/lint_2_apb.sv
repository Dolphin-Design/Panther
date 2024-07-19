// Copyright 2014-2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

module lint_2_apb
#(
    parameter REG_OUT        = 0,
    parameter ADDR_WIDTH     = 32,
    parameter DATA_WIDTH     = 32,
    parameter BE_WIDTH       = DATA_WIDTH/8,
    parameter ID_WIDTH       = 10,
    parameter AUX_WIDTH      = 14,
    parameter AUX_USER_BASE  = 12,
    parameter AUX_USER_END   = 12
)
(
    input                             clk,
    input                             rst_n,

    // Req
    input                             data_req_i,
    input        [ADDR_WIDTH-1:0]     data_add_i,
    input                             data_we_n_i,
    input        [DATA_WIDTH-1:0]     data_wdata_i,
    input        [BE_WIDTH-1:0]       data_be_i,
    input        [AUX_WIDTH-1:0]      data_aux_i,
    input        [ID_WIDTH-1:0]       data_ID_i,
    output logic                      data_gnt_o,

    // Resp
    output logic                      data_r_valid_o,
    output logic [DATA_WIDTH-1:0]     data_r_rdata_o,
    output logic                      data_r_opc_o,
    output logic [AUX_WIDTH-1:0]      data_r_aux_o,
    output logic [ID_WIDTH-1:0]       data_r_ID_o,


    output logic [ADDR_WIDTH-1:0]     master_PADDR,
    output logic [DATA_WIDTH-1:0]     master_PWDATA,
    output logic                      master_PWRITE,
    output logic                      master_PSEL,
    output logic                      master_PENABLE,
    output logic [2:0]                master_PPROT,
    output logic [BE_WIDTH-1:0]       master_PSTRB,
    output logic [(AUX_USER_END-AUX_USER_BASE):(AUX_USER_BASE-AUX_USER_BASE)]       master_PUSER,
    input        [DATA_WIDTH-1:0]     master_PRDATA,
    input                             master_PREADY,
    input                             master_PSLVERR
);

  enum logic [1:0] {IDLE, WAIT, WAIT_PREADY, DISPATCH_RDATA } CS,NS;

  logic                       sample_req_info;

  logic                       sample_rdata;
  logic                       data_r_valid_NS;


  logic [ADDR_WIDTH-1:0]      master_PADDR_Q;
  logic [DATA_WIDTH-1:0]      master_PWDATA_Q;
  logic                       master_PWRITE_Q;
  
  logic s_write;

  assign master_PADDR  = master_PADDR_Q ;
  assign master_PWDATA = master_PWDATA_Q;
  assign master_PWRITE = master_PWRITE_Q;
  assign master_PPROT  = 3'b010;

  assign s_write = ~data_we_n_i;

generate
  if (REG_OUT) begin : g_reg_out

  always_ff @(posedge clk or negedge rst_n)
  begin
    if (~rst_n) begin
      CS              <= IDLE;
      data_r_aux_o    <= '0;
      data_r_ID_o     <= '0;
      master_PADDR_Q  <= '0;
      master_PWDATA_Q <= '0;
      master_PWRITE_Q <= '0;
      master_PSTRB    <= '0 ;
      master_PUSER    <= '0 ;
      data_r_rdata_o <= '0;
      data_r_opc_o   <= '0;
      data_r_valid_o <= 1'b0;
    end
    else begin
      CS <= NS;
      if (sample_req_info) begin
        data_r_aux_o    <= data_aux_i;
        data_r_ID_o     <= data_ID_i;
        master_PADDR_Q  <= (s_write) ? {data_add_i[ADDR_WIDTH-1:2], 2'b00}: data_add_i;
        master_PWDATA_Q <= data_wdata_i;
        master_PWRITE_Q <= s_write;
        master_PSTRB    <= (s_write) ? data_be_i : '0;
        master_PUSER    <= data_aux_i[AUX_USER_END:AUX_USER_BASE] ;
      end
      if (sample_rdata) begin
        data_r_rdata_o <= master_PRDATA;
        data_r_opc_o   <= master_PSLVERR;
      end
      data_r_valid_o   <= data_r_valid_NS;
    end
  end
  
  always_comb
  begin  
      master_PSEL     = 1'b0;
      master_PENABLE  = 1'b0;
      sample_req_info = 1'b0;
      data_gnt_o      = 1'b0;
      sample_rdata    = 1'b0;
      data_r_valid_NS = 1'b0;

    case (CS)
      IDLE: begin
        data_r_valid_NS = 1'b0;
        if (data_req_i) begin
          sample_req_info = 1'b1;
          data_gnt_o = 1'b1;
          NS = WAIT;
        end
        else begin
          NS = IDLE;
        end
      end

      WAIT: begin
        master_PSEL    = 1'b1;
        NS = WAIT_PREADY;
      end

      WAIT_PREADY: begin
        master_PSEL    = 1'b1;
        master_PENABLE = 1'b1;
        sample_rdata   = master_PREADY;
        data_r_valid_NS = master_PREADY;
        if (master_PREADY) begin
          NS = DISPATCH_RDATA;
        end
        else begin
          NS = WAIT_PREADY;
        end
      end

      DISPATCH_RDATA: begin
        NS = IDLE;
        data_gnt_o = 1'b0;
      end

      default: begin
        NS = IDLE;
      end

    endcase
   end

  end

  else

  begin : g_reg_out_no

  always_ff @(posedge clk or negedge rst_n)
  begin
    if (~rst_n) begin
      CS              <= IDLE;
      data_r_aux_o    <= '0;
      data_r_ID_o     <= '0;
      master_PADDR_Q  <= '0;
      master_PWDATA_Q <= '0;
      master_PWRITE_Q <= '0;
      master_PSTRB    <= '0 ;
      master_PUSER    <= '0 ;
    end
    else begin
      CS <= NS;
      if (sample_req_info) begin
        data_r_aux_o    <= data_aux_i;
        data_r_ID_o     <= data_ID_i;
        master_PADDR_Q  <= (s_write) ? {data_add_i[ADDR_WIDTH-1:2], 2'b00}: data_add_i;
        master_PWDATA_Q <= data_wdata_i;
        master_PWRITE_Q <= s_write;
        master_PSTRB    <= (s_write) ? data_be_i : '0;
        master_PUSER    <= data_aux_i[AUX_USER_END:AUX_USER_BASE] ;
      end
    end
  end
  
  always_comb
  begin  
      master_PSEL     = 1'b0;
      master_PENABLE  = 1'b0;
      sample_req_info = 1'b0;
      data_gnt_o      = 1'b0;
      data_r_rdata_o =  master_PRDATA;
      data_r_opc_o   =  master_PSLVERR;
      data_r_valid_o = 1'b0;

    case (CS)
      IDLE: begin
        if (data_req_i) begin
          sample_req_info = 1'b1;
          data_gnt_o = 1'b1;
          NS = WAIT;
        end
        else begin
          NS = IDLE;
        end
      end

      WAIT: begin
        master_PSEL    = 1'b1;
        NS = WAIT_PREADY;
      end

      WAIT_PREADY: begin
        master_PSEL    = 1'b1;
        master_PENABLE = 1'b1;
        data_r_valid_o = master_PREADY;
        if (master_PREADY) begin
          NS = DISPATCH_RDATA;
        end
        else begin
          NS = WAIT_PREADY;
        end
      end

      DISPATCH_RDATA: begin
        NS = IDLE;
        data_gnt_o = 1'b0;
      end

      default: begin
        NS = IDLE;
      end

    endcase
   end

  end

endgenerate

endmodule // lint_2_apb
