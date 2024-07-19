// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

/*
 * cluster_timer_wrap.sv
 * Davide Rossi <davide.rossi@unibo.it>
 * Antonio Pullini <pullinia@iis.ee.ethz.ch>
 * Igor Loi <igor.loi@unibo.it>
 * Francesco Conti <fconti@iis.ee.ethz.ch>
 */

module cluster_timer_wrap
#(
  parameter ID_WIDTH  = 2
)
(
  input  logic          clk_i,
  input  logic          rst_ni,
  input  logic          ref_clk_i,
  
  XBAR_PERIPH_BUS.Slave periph_slave,
  
  input  logic          event_lo_i,
  input  logic          event_hi_i,
  
  output logic          irq_lo_o,
  output logic          irq_hi_o,
  
  output logic          busy_o,

  input  logic          scan_ckgt_enable_i
);


  APB_BUS#(.APB_ADDR_WIDTH(12)) timer_apb_bus();

  lint_2_apb #(
      .ADDR_WIDTH     ( 12                             ),
      .DATA_WIDTH     ( 32                             ),
      .BE_WIDTH       ( 4                              ),
      .ID_WIDTH       ( ID_WIDTH                       ),
      .AUX_WIDTH      ( 1                              ),
      .AUX_USER_BASE  ( 0                              ),
      .AUX_USER_END   ( 0                              ) 
    ) lint_2_apb_i (
      .clk            ( clk_i                          ),
      .rst_n          ( rst_ni                         ),
      .data_req_i     ( periph_slave.req               ),
      .data_add_i     ( periph_slave.add         [11:0]),
      .data_we_n_i    ( periph_slave.we_n              ), // 0: write, 1: read, polarity fixed in core_region
      .data_wdata_i   ( periph_slave.wdata             ),
      .data_be_i      ( periph_slave.be                ),
      .data_aux_i     ( '0                             ),
      .data_ID_i      ( periph_slave.id                ),
      .data_gnt_o     ( periph_slave.gnt               ),
      .data_r_valid_o ( periph_slave.r_valid           ),
      .data_r_rdata_o ( periph_slave.r_rdata           ),
      .data_r_opc_o   ( periph_slave.r_opc             ),
      .data_r_aux_o   (                                ),
      .data_r_ID_o    ( periph_slave.r_id              ),

      .master_PADDR   ( timer_apb_bus.paddr            ),
      .master_PWDATA  ( timer_apb_bus.pwdata           ),
      .master_PWRITE  ( timer_apb_bus.pwrite           ),
      .master_PSEL    ( timer_apb_bus.psel             ),
      .master_PENABLE ( timer_apb_bus.penable          ),
      .master_PPROT   (                                ),
      .master_PSTRB   (                                ),
      .master_PUSER   (                                ),
      .master_PRDATA  ( timer_apb_bus.prdata           ),
      .master_PREADY  ( timer_apb_bus.pready           ),
      .master_PSLVERR ( timer_apb_bus.pslverr          )
    );

  apb_timer_unit timer_unit_i (
      .HCLK           (clk_i                           ),
      .HRESETn        (rst_ni                          ),
      .PADDR          (timer_apb_bus.paddr             ),
      .PWDATA         (timer_apb_bus.pwdata            ),
      .PWRITE         (timer_apb_bus.pwrite            ),
      .PSEL           (timer_apb_bus.psel              ),
      .PENABLE        (timer_apb_bus.penable           ),
      .PRDATA         (timer_apb_bus.prdata            ),
      .PREADY         (timer_apb_bus.pready            ),
      .PSLVERR        (timer_apb_bus.pslverr           ),
      .dft_cg_enable_i(scan_ckgt_enable_i              ),
      .ref_clk_i      (ref_clk_i                       ),
      .event_lo_i     (event_lo_i                      ),
      .event_hi_i     (event_hi_i                      ),
      .timer_val_lo_o (                                ),
      .irq_lo_o       (irq_lo_o                        ),
      .irq_hi_o       (irq_hi_o                        ),
      .busy_o         (busy_o                          )
    );

endmodule
