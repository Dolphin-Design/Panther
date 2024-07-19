////////////////////////////////////////////////////////////////////////////////
//                                                                            //
// Copyright 2018 ETH Zurich and University of Bologna.                       //
// Copyright and related rights are licensed under the Solderpad Hardware     //
// License, Version 0.51 (the "License"); you may not use this file except in //
// compliance with the License.  You may obtain a copy of the License at      //
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law  //
// or agreed to in writing, software, hardware and materials distributed under//
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR     //
// CONDITIONS OF ANY KIND, either express or implied. See the License for the //
// specific language governing permissions and limitations under the License. //
//                                                                            //
// Company:        Micrel Lab @ DEIS - University of Bologna                  //
//                    Viale Risorgimento 2 40136                              //
//                    Bologna - fax 0512093785 -                              //
//                                                                            //
// Engineer:       Igor Loi - igor.loi@unibo.it                               //
//                                                                            //
// Additional contributions by:                                               //
//                                                                            //
//                                                                            //
//                                                                            //
// Create Date:    01/01/2019                                                 //
// Design Name:    FPU_INTERCONNECT                                           //
// Module Name:    FanInPrimitive_Resp_FPU                                    //
// Project Name:   VEGA                                                       //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:                                                               //
//                                                                            //
//                                                                            //
//                                                                            //
//                                                                            //
// Revision:                                                                  //
// Revision v0.1 - 01/01/2019 : File Created                                  //
//                                                                            //
// Additional Comments:                                                       //
//                                                                            //
//                                                                            //
//                                                                            //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module FanInPrimitive_Resp_FPU
#(
    parameter FLAG_WIDTH = 8,
    parameter DATA_WIDTH = 32
)
(
    // UPSTREAM SIDE 
    input  logic [DATA_WIDTH-1:0]        data_r_rdata0_i,
    input  logic [DATA_WIDTH-1:0]        data_r_rdata1_i,
    input  logic                         data_r_valid0_i,
    input  logic                         data_r_valid1_i,
    input  logic [FLAG_WIDTH-1:0]        data_r_flag0_i,
    input  logic [FLAG_WIDTH-1:0]        data_r_flag1_i,

    // DOWNSTREAM SIDE
    output logic [DATA_WIDTH-1:0]        data_r_rdata_o,
    output logic                         data_r_valid_o,
    output logic [FLAG_WIDTH-1:0]        data_r_flag_o
);

    // Selector for the FanOut multiplexer
    logic                  SEL;

    // VAlid is simply the or of the two requests
    assign data_r_valid_o = data_r_valid1_i | data_r_valid0_i;

    // FIXME: (req0 & req1) must be always 0
    assign SEL = data_r_valid1_i;


    // SEL CONTROLLER
    always_comb
    begin : FanOut_MUX2
        case(SEL) 
          1'b0: begin data_r_rdata_o  = data_r_rdata0_i; data_r_flag_o = data_r_flag0_i; end
          1'b1: begin data_r_rdata_o  = data_r_rdata1_i; data_r_flag_o = data_r_flag1_i; end
        endcase
    end
endmodule
