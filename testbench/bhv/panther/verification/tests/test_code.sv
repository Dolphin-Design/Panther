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
//      Function: Panther test
//
//==============================================================================

import sv_axi_pkg::*;

module panther_top_test #(
    parameter integer AXI_ADDR_WIDTH = 32,
    parameter integer AXI_DATA_WIDTH = 32,
    parameter integer AXI_ID_WIDTH   = 8 ,
    parameter integer AXI_USER_WIDTH = 32
) (
    sv_axi_interface data_slave
);

    sv_axi_env #(AXI_ADDR_WIDTH, AXI_DATA_WIDTH, AXI_ID_WIDTH, AXI_USER_WIDTH) axi_data_slave_env;

    initial begin
        axi_data_slave_env = new(data_slave, 0);
    end


    initial begin
        //read and prepare all masters (drivers) from input files
        $display("\n[TEST] Generating transactions");

        fork
            axi_data_slave_env.axi_gen.send_transactions_from_file("data_slave_input.dat");
        join_none;

        //calling run for all axi_if environments
        $display("\n[TEST] Running transactions");
        fork
            axi_data_slave_env.run();
        join

        $display("\n[TEST] Checking Results");
        fork
            axi_data_slave_env.axi_scb.compare_transactions_with_file("data_slave_input.dat");
        join

        $finish;
    end
endmodule
