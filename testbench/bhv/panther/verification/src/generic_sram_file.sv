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
//      Function: Generic SRAM model
//
//==============================================================================

module generic_sram_file(
    clk,
    addr,
    ce_n,
    we_n,
    be_n,
    datain,
    dataout
);

    parameter PARAMETER_ADDR_SIZE  = 1;
    parameter PARAMETER_WORD_SIZE  = 1;
    parameter PARAMETER_FILE_NAME  = "";
    parameter PARAMETER_WMASK_SIZE = 8;
    parameter PARAMETER_BE_WIDTH   = $clog2(PARAMETER_WORD_SIZE / PARAMETER_WMASK_SIZE);

    input                            clk;
    input  [PARAMETER_ADDR_SIZE-1:0] addr;
    input                            ce_n;
    input                            we_n;
    input  [PARAMETER_BE_WIDTH-1:0]  be_n;
    input  [PARAMETER_WORD_SIZE-1:0] datain;
    output [PARAMETER_WORD_SIZE-1:0] dataout;


    reg  [PARAMETER_WMASK_SIZE-1:0] ram_array [(1 << (PARAMETER_ADDR_SIZE + 2)) - 1:0];
    reg  [PARAMETER_WORD_SIZE-1:0]  dataout;
    reg  [PARAMETER_WORD_SIZE-1:0]  sdataout;

    wire [PARAMETER_ADDR_SIZE + PARAMETER_BE_WIDTH-1:0] byte_addr;

    assign byte_addr = {addr, {PARAMETER_BE_WIDTH{1'b0}}};


    initial begin : init_patterns
        if (PARAMETER_FILE_NAME != "") begin
            $readmemh(PARAMETER_FILE_NAME, ram_array);
                $display("Memory loaded from %s", PARAMETER_FILE_NAME);
            end
        else begin
            for (int i = 0; i < 1 << (PARAMETER_ADDR_SIZE + 2); i++) begin
                ram_array[i] = {PARAMETER_WMASK_SIZE{1'b0}};
            end
        end
        sdataout = {PARAMETER_WORD_SIZE{1'b0}};
    end


    always @(posedge clk) begin : p_genram
    	if (!ce_n && !we_n) begin
            if (!be_n[0]) 
                ram_array[byte_addr] <= datain[7:0];
            if (!be_n[1]) 
                ram_array[byte_addr + 2'd1] <= datain[15:8];
            if (!be_n[2]) 
                ram_array[byte_addr + 2'd2] <= datain[23:16];
            if (!be_n[3]) 
                ram_array[byte_addr + 2'd3] <= datain[31:24];
    	end
    end


    always @(posedge clk) begin : p_genout
        if (!ce_n && we_n) begin
            dataout <= {ram_array[(byte_addr + 2'b11)] , ram_array[(byte_addr + 2'b10)] , ram_array[(byte_addr + 2'b01)] , ram_array[byte_addr]};
            sdataout <= {ram_array[(byte_addr + 2'b11)] , ram_array[(byte_addr + 2'b10)] , ram_array[(byte_addr + 2'b01)], ram_array[byte_addr]};
        end
        else begin
            dataout <= sdataout;
        end
    end

endmodule
