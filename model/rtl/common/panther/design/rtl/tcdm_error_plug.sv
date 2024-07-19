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

module tcdm_error_plug
(
    input logic           i_clk,
    input logic           i_rst_n,
    XBAR_TCDM_BUS.Slave   tcdm_slave
);

    assign tcdm_slave.r_opc    = 1'b1;
    assign tcdm_slave.gnt      = tcdm_slave.req;
    assign tcdm_slave.r_rdata  = 32'hDEAD_BEEF;

    always_ff @( posedge i_clk, negedge i_rst_n ) begin : ff_r_valid
        if(i_rst_n == '0) begin
            tcdm_slave.r_valid = 1'b0;
        end else begin
            tcdm_slave.r_valid = tcdm_slave.req;
        end
    end

endmodule
