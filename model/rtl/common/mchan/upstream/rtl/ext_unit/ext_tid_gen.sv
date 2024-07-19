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

module ext_tid_gen
#(
  parameter int EXT_TID_WIDTH = 4
)
(
  input  logic                     clk_i        ,
  input  logic                     rst_ni       ,
  output logic                     valid_tid_o  ,
  output logic [EXT_TID_WIDTH-1:0] tid_o        ,
  input  logic                     incr_i       ,
  input  logic [EXT_TID_WIDTH-1:0] tid_i        ,
  input  logic                     release_tid_i
);
   
  localparam int NB_OUTSND_TRANS = 2**EXT_TID_WIDTH;
   
  integer                  i;
  
  logic [15:0]             tid_table;
  logic [15:0]             s_tid;
   
  always_ff @(posedge clk_i, negedge rst_ni) begin : p_tid_table_seq
    if(rst_ni == 1'b0) begin
      for(i = 0; i < 16; i++) begin
        if (i < NB_OUTSND_TRANS) begin
          tid_table[i] <= 1'b0;
        end else begin
          tid_table[i] <= 1'b1;
        end
      end
    end else begin
      if(release_tid_i) begin
        tid_table[tid_i] <= 1'b0;
      end else;
      
      if(incr_i) begin
        if (tid_table[0]==1'b0) begin
          tid_table[0] <= 1'b1;
        end else if (tid_table[1:0]==2'b01) begin
          tid_table[1]<= 1'b1;
        end else if (tid_table[2:0]==3'b011) begin
          tid_table[2]<= 1'b1;
        end else if (tid_table[3:0]==4'b0111) begin
          tid_table[3] <= 1'b1;
        end else if (tid_table[4:0]==5'b0_1111) begin
          tid_table[4] <= 1'b1;
        end else if (tid_table[5:0]==6'b01_1111) begin
          tid_table[5] <= 1'b1;
        end else if (tid_table[6:0]==7'b011_1111) begin
          tid_table[6] <= 1'b1;            
        end else if (tid_table[7:0]==8'b0111_1111) begin
          tid_table[7] <= 1'b1;
        end else if (tid_table[8:0]==9'b0_1111_1111) begin
          tid_table[8] <= 1'b1;
        end else if (tid_table[9:0]==10'b01_1111_1111) begin
          tid_table[9] <= 1'b1;
        end else if (tid_table[10:0]==11'b011_1111_1111) begin
          tid_table[10] <= 1'b1;
        end else if (tid_table[11:0]==12'b0111_1111_1111) begin
          tid_table[11] <= 1'b1;
        end else if (tid_table[12:0]==13'b0_1111_1111_1111) begin
          tid_table[12] <= 1'b1;
        end else if (tid_table[13:0]==14'b01_1111_1111_1111) begin
          tid_table[13] <= 1'b1;
        end else if (tid_table[14:0]==15'b011_1111_1111_1111) begin
          tid_table[14] <= 1'b1;
        end else if (tid_table[15:0]==16'b0111_1111_1111_1111) begin
          tid_table[15] <= 1'b1;
        end
      end
    end
  end

  always_comb begin : p_tid_table_comb

    if (tid_table[0]==1'b0) begin
      s_tid            = 0;
      valid_tid_o      = 1'b1;
    end else if (tid_table[1:0]==2'b01) begin
      s_tid            = 1;
      valid_tid_o      = 1'b1;
    end else if (tid_table[2:0]==3'b011) begin
      s_tid            = 2;
      valid_tid_o      = 1'b1;
    end else if (tid_table[3:0]==4'b0111) begin
      s_tid            = 3;
      valid_tid_o      = 1'b1;
    end else if (tid_table[4:0]==5'b0_1111) begin
      s_tid            = 4;
      valid_tid_o      = 1'b1;
    end else if (tid_table[5:0]==6'b01_1111) begin
      s_tid            = 5;
      valid_tid_o      = 1'b1;
    end else if (tid_table[6:0]==7'b011_1111) begin
      s_tid            = 6;
      valid_tid_o      = 1'b1;        
    end else if (tid_table[7:0]==8'b0111_1111) begin
      s_tid            = 7;
      valid_tid_o      = 1'b1;
    end else if (tid_table[8:0]==9'b0_1111_1111) begin
      s_tid            = 8;
      valid_tid_o      = 1'b1;
    end else if (tid_table[9:0]==10'b01_1111_1111) begin
      s_tid            = 9;
      valid_tid_o      = 1'b1;
    end else if (tid_table[10:0]==11'b011_1111_1111) begin
      s_tid            = 10;
      valid_tid_o      = 1'b1;
    end else if (tid_table[11:0]==12'b0111_1111_1111) begin
      s_tid            = 11;
      valid_tid_o      = 1'b1;
    end else if (tid_table[12:0]==13'b0_1111_1111_1111) begin
      s_tid            = 12;
      valid_tid_o      = 1'b1;
    end else if (tid_table[13:0]==14'b01_1111_1111_1111) begin
      s_tid            = 13;
      valid_tid_o      = 1'b1;
    end else if (tid_table[14:0]==15'b011_1111_1111_1111) begin
      s_tid            = 14;
      valid_tid_o      = 1'b1;
    end else if (tid_table[15:0]==16'b0111_1111_1111_1111) begin
      s_tid            = 15;
      valid_tid_o      = 1'b1;
    end else begin 
       s_tid            = 4'b0000;
       valid_tid_o      = 1'b0;
    end
  end

  assign tid_o = s_tid[EXT_TID_WIDTH-1:0];

  endmodule
