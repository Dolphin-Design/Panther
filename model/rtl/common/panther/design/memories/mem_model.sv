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

module GENERIC_MEM #(
  parameter ADDR_WIDTH = 10,
  parameter DATA_WIDTH = 32,
  parameter NB_LANES   = 4
)
(
  input  logic                    CLK, CEN, RDWEN,
  input  logic [DATA_WIDTH - 1:0] BW,

  input  logic [ADDR_WIDTH - 1:0] A,

  input  logic [DATA_WIDTH - 1:0] D,
  output logic [DATA_WIDTH - 1:0] Q
);

  localparam   DATA_LANES_WIDTH = DATA_WIDTH/NB_LANES;
  localparam   NUM_WORDS        = 2**ADDR_WIDTH;

  logic [         DATA_WIDTH-1:0]  MEM                 [NUM_WORDS-1:0];

  genvar i,j;

  generate
    for (i=0; i < NB_LANES; i++)
      begin
        for (j=0; j < DATA_LANES_WIDTH; j++)
          begin
            always @ (posedge CLK)
              begin
                if ( CEN == 1'b0 )
                  begin
                    if ( RDWEN == 1'b0 )
                      begin
                        if ( BW[i*DATA_LANES_WIDTH + j] == 1'b1 )
                          begin
                            MEM[A][i*DATA_LANES_WIDTH + j] <= D[i*DATA_LANES_WIDTH + j];
                          end
                      end
                    else 
                      if(RDWEN == 1'b1)
                        begin
                          Q[i*DATA_LANES_WIDTH + j] <= MEM[A][i*DATA_LANES_WIDTH + j];
                        end
                  end
              end
          end
      end
  endgenerate

endmodule
