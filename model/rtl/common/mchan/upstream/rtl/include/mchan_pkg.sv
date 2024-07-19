// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License. You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

// Davide Rossi <davide.rossi@unibo.it>

package mchan_pkg;

    // MCHAN OPCODES
    localparam logic [3:0] MCHAN_OP_1B     =  4'b0000  ;
    localparam logic [3:0] MCHAN_OP_2B     =  4'b0001  ;
    localparam logic [3:0] MCHAN_OP_4B     =  4'b0010  ;
    localparam logic [3:0] MCHAN_OP_8B     =  4'b0011  ;
    localparam logic [3:0] MCHAN_OP_16B    =  4'b0100  ;
    localparam logic [3:0] MCHAN_OP_32B    =  4'b0101  ;
    localparam logic [3:0] MCHAN_OP_64B    =  4'b0110  ;
    localparam logic [3:0] MCHAN_OP_128B   =  4'b0111  ;
    localparam logic [3:0] MCHAN_OP_256B   =  4'b1000  ;
    localparam logic [3:0] MCHAN_OP_512B   =  4'b1001  ;
    localparam logic [3:0] MCHAN_OP_1024B  =  4'b1010  ;
    localparam logic [3:0] MCHAN_OP_2048B  =  4'b1011  ;
    localparam logic [3:0] MCHAN_OP_4096B  =  4'b1100  ;
    localparam logic [3:0] MCHAN_OP_8192B  =  4'b1101  ;
    localparam logic [3:0] MCHAN_OP_16384B =  4'b1110  ;
    localparam logic [3:0] MCHAN_OP_32768B =  4'b1111  ;
    
    // MCHAN OPERATIONS
    localparam int MCHAN_OP_TX             =  0        ; // TX OPERATION (FROM TCDM TO EXTERNAL MEMORY)
    localparam int MCHAN_OP_RX             =  1        ; // RX OPERATION (FROM EXTERNAL MEMORY TO TCDM)
   
    //MCHAN CORE INTERFACE ADDRESS SPACE
    localparam int MCHAN_CMD_ADDR      =  0        ;
    localparam int MCHAN_STATUS_ADDR   =  4        ;

    // WIDTH OF MCHAN OPCODES
    localparam int MCHAN_LEN_WIDTH     =  17       ;
    localparam int TWD_COUNT_WIDTH     =  32       ;
    localparam int TWD_STRIDE_WIDTH    =  32       ;

    localparam int MCHAN_OPC_WIDTH     =  1        ;
    localparam int TCDM_OPC_WIDTH      =  1        ;
    localparam int EXT_OPC_WIDTH       =  1        ;

endpackage : mchan_pkg
