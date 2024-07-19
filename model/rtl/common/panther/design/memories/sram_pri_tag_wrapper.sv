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

module sram_pri_tag_wrapper 
  #(parameter ADDR_WIDTH  =  4,
    parameter DATA_WIDTH  = 24,
    parameter PRI_NB_WAYS =  2)
  ( CLK, CEN, WEN, BEN, A, D, Q, T_LOGIC);

  input CLK, CEN, WEN;
  input [1:0] BEN;
  input [ADDR_WIDTH - 1:0] A;
  input [DATA_WIDTH - 1:0] D;
  input T_LOGIC;

  output[DATA_WIDTH - 1:0] Q;

  logic [DATA_WIDTH - 1:0] BW;

  localparam NB_LANES = PRI_NB_WAYS;

  genvar lane,i;
  
  generate

    for (lane=0 ; lane<NB_LANES ; lane++) begin : g_bw_lane
      for (i=0 ; i<DATA_WIDTH/NB_LANES ; i++) begin : g_bw
        assign BW[i + lane*DATA_WIDTH/NB_LANES] = ~BEN[lane];
      end
    end

  endgenerate

  GENERIC_MEM #(
    .ADDR_WIDTH (ADDR_WIDTH),
    .DATA_WIDTH (DATA_WIDTH),
    .NB_LANES   (NB_LANES  )
  ) i_memcut (
    .CLK(CLK), .CEN(CEN), .RDWEN(WEN), .BW(BW), .A(A), .D(D), .Q(Q)
  );

endmodule
