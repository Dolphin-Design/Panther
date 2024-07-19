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

//------------------------------------------------------------------------------
//
//  HARDMUX IP I/O description:
//   - i_sel : MUX sel
//   - i_i0  : MUX Input connected to the MUX output when i_sel set to '0'
//   - i_i1  : MUX Input connected to the MUX output when i_sel set to '1'
//   - o_z   : MUX output
//
//------------------------------------------------------------------------------

module hard_mux2
(
  input   i_sel ,
  input   i_i0  ,
  input   i_i1  ,
  output  o_z
) ;

assign  o_z  =   ( i_sel == 1'b1 ) ? i_i1 : i_i0 ;

endmodule
