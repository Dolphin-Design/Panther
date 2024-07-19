// Copyright 2014-2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

// ============================================================================= //
// Company:        Multitherman Laboratory @ DEIS - University of Bologna        //
//                    Viale Risorgimento 2 40136                                 //
//                    Bologna - fax 0512093785 -                                 //
//                                                                               //
// Engineer:       Igor Loi - igor.loi@unibo.it                                  //
//                                                                               //
//                                                                               //
// Additional contributions by:                                                  //
//                                                                               //
//                                                                               //
//                                                                               //
// Create Date:    01/02/2014                                                    //
// Design Name:    AXI 4 INTERCONNECT                                            //
// Module Name:    axi_FanInPrimitive_Req                                        //
// Project Name:   PULP                                                          //
// Language:       SystemVerilog                                                 //
//                                                                               //
// Description:   a 2 input round robin arbiter with lock Mechanism for          //
//                exclusive access                                               //
//                                                                               //
// Revision:                                                                     //
// Revision v0.1 - 01/02/2014 : File Created                                     //
//                                                                               //
//                                                                               //
//                                                                               //
//                                                                               //
//                                                                               //
//                                                                               //
// ============================================================================= //

module axi_FanInPrimitive_Req
#(
      parameter int AUX_WIDTH = 32,
      parameter int ID_WIDTH = 16
)
(
      input logic                                       clk    ,
      input logic                                       rst_n  ,
      input logic                                       RR_FLAG,

      // LEFT SIDE
      input  logic [AUX_WIDTH-1:0]                      data_AUX0_i,
      input  logic [AUX_WIDTH-1:0]                      data_AUX1_i,

      input  logic                                      data_req0_i,
      input  logic                                      data_req1_i,
      input  logic [ID_WIDTH-1:0]                       data_ID0_i,
      input  logic [ID_WIDTH-1:0]                       data_ID1_i,
      output logic                                      data_gnt0_o,
      output logic                                      data_gnt1_o,
      // RIGTH SIDE
      output logic [AUX_WIDTH-1:0]                      data_AUX_o,
      output logic                                      data_req_o,
      output logic [ID_WIDTH-1:0]                       data_ID_o,
      input  logic                                      data_gnt_i,

      input  logic                                      lock_EXCLUSIVE,
      input  logic                                      SEL_EXCLUSIVE
);



        logic   SEL;
        logic   SEL_en;
        logic   RR_FLAG_int;
        logic   prio_r;
        logic   pending_req;  //If pending request, used stored priority to avoid preemption
                              //0 = use RR_FLAG, 1 = use stored priority
        // If not prioritary request pass, create fake rr_flag updated so no preemption
        assign SEL_en = (data_req0_i ^ data_req1_i) & ~data_gnt_i;

        assign RR_FLAG_int = (pending_req) ? prio_r : RR_FLAG;

        always_comb
        begin
          if(lock_EXCLUSIVE)
          begin
            data_req_o   = (SEL_EXCLUSIVE) ? data_req1_i : data_req0_i;
            data_gnt0_o  = (SEL_EXCLUSIVE) ? 1'b0        : data_gnt_i;
            data_gnt1_o  = (SEL_EXCLUSIVE) ? data_gnt_i  : 1'b0;
            SEL          =  SEL_EXCLUSIVE;
          end
          else
          begin
            data_req_o  =     data_req0_i | data_req1_i;
            data_gnt0_o =    (( data_req0_i & ~data_req1_i) | ( data_req0_i & ~RR_FLAG_int)) & data_gnt_i;
            data_gnt1_o =    ((~data_req0_i &  data_req1_i) | ( data_req1_i &  RR_FLAG_int)) & data_gnt_i;
            SEL         =    ~data_req0_i | ( RR_FLAG_int & data_req1_i);
          end
        end




        //MUXES AND DEMUXES
        always_comb
        begin : FanIn_MUX2
            case(SEL)
            1'b0:       begin //PRIORITY ON CH_0
                          data_AUX_o   = data_AUX0_i;
                          data_ID_o    = data_ID0_i;
                        end

            1'b1:       begin //PRIORITY ON CH_1
                          data_AUX_o   = data_AUX1_i;
                          data_ID_o    = data_ID1_i;
                        end

            endcase
        end

        always_ff @( posedge clk, negedge rst_n ) begin : sel_lock_ff
          if(~rst_n) begin
            pending_req <= '0;
            prio_r      <= '0;
          end else begin
            if(SEL_en) begin
              pending_req <= 1'b1;
              prio_r      <= SEL;
            end else if (data_gnt_i) begin
              pending_req <= 1'b0;
            end
          end
        end


endmodule
