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

class sv_axi_trans #(parameter int AXI_ADDR_WIDTH = 32, parameter int AXI_DATA_WIDTH = 64, parameter int AXI_ID_WIDTH = 4, parameter int AXI_USER_WIDTH = 6);

    rand int w_en;
    rand int r_en;

    rand bit [AXI_ADDR_WIDTH-1:0] waddress;
    rand bit [AXI_ADDR_WIDTH-1:0] raddress;

    rand bit [AXI_DATA_WIDTH-1:0] wdata[];
         bit [AXI_DATA_WIDTH-1:0] rdata[];

    rand int wlen;
    rand int rlen;

    bit wait_eoc = 0;

    constraint c_len {
        solve wlen before wdata;

        wlen inside {[0:19]};
        rlen inside {[0:19]};

        wdata.size() == wlen;
    }

endclass //sv_axi_trans
