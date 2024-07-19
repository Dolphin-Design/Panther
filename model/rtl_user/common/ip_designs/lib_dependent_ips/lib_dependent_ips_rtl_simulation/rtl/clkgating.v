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

module clkgating (

  input  i_clk,
  input  i_test_mode,
  input  i_enable,
  output o_gated_clk

) ;

  reg LatchedEnable ;
  wire w_Enable ;

  assign w_Enable = ( i_enable == 1'b1 ) ? 1'b1 : i_test_mode ;

  always @( i_clk or w_Enable ) begin
    if ( i_clk == 1'b0 ) begin
      LatchedEnable <= w_Enable ; // Load new data
    end
  end

  assign o_gated_clk = i_clk && LatchedEnable ;

endmodule

