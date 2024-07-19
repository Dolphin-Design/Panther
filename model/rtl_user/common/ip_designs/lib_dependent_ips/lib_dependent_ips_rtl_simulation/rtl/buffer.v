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

module buffer (

  i_in,
  o_out

) ;


  //============================================================================
  // Parameter
  //============================================================================

  parameter DELAY = 1 ;


  //============================================================================
  // Signals
  //============================================================================

  input  i_in ;
  output o_out ;


  //============================================================================
  // Buffer
  //============================================================================

  buf #( DELAY ) u_buf ( o_out, i_in ) ;


endmodule

