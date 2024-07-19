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
 * dmac_wrap.sv
 * Davide Rossi <davide.rossi@unibo.it>
 * Antonio Pullini <pullinia@iis.ee.ethz.ch>
 * Igor Loi <igor.loi@unibo.it>
 * Francesco Conti <fconti@iis.ee.ethz.ch>
 */

module dmac_wrap
#(
  parameter NB_CTRLS           = 2,
  parameter NB_CORES           = 8,
  parameter NB_OUTSND_BURSTS   = 8,
  parameter MCHAN_BURST_LENGTH = 256,
  parameter AXI_ADDR_WIDTH     = 32,
  parameter AXI_DATA_WIDTH     = 64,
  parameter AXI_USER_WIDTH     = 6,
  parameter AXI_ID_WIDTH       = 4,
  parameter PE_ID_WIDTH        = 1,
  parameter TCDM_ADD_WIDTH     = 13,
  parameter DATA_WIDTH         = 32,
  parameter ADDR_WIDTH         = 32,
  parameter BE_WIDTH           = DATA_WIDTH/8,
  parameter CTRL_ADD_WIDTH     = 10
)
( 
  input logic  i_clk,
  input logic  i_rst_n,
  input logic  i_scan_ckgt_enable,

  XBAR_TCDM_BUS.Slave   ctrl_slave[NB_CORES-1:0],
  XBAR_PERIPH_BUS.Slave cl_ctrl_slave,
  XBAR_PERIPH_BUS.Slave fc_ctrl_slave,
   
  hci_core_intf.master tcdm_master[3:0],
  AXI_BUS.Master ext_master,
  output logic o_term_event_cl,
  output logic o_term_irq_cl,
  output logic o_term_event_pe,
  output logic o_term_irq_pe,
  output logic [NB_CORES-1:0] o_term_event,
  output logic [NB_CORES-1:0] o_term_irq,
  output logic o_busy
);
  
  //   CORE --> MCHAN CTRL INTERFACE BUS SIGNALS
  logic [NB_CTRLS-1:0][DATA_WIDTH-1:0]  s_ctrl_bus_wdata;
  logic [NB_CTRLS-1:0][CTRL_ADD_WIDTH-1:0]  s_ctrl_bus_add;
  logic [NB_CTRLS-1:0]                  s_ctrl_bus_req;
  logic [NB_CTRLS-1:0]                  s_ctrl_bus_we_n;
  logic [NB_CTRLS-1:0][BE_WIDTH-1:0]    s_ctrl_bus_be;
  logic [NB_CTRLS-1:0][PE_ID_WIDTH-1:0] s_ctrl_bus_id;
  logic [NB_CTRLS-1:0]                  s_ctrl_bus_gnt;
  logic [NB_CTRLS-1:0][DATA_WIDTH-1:0]  s_ctrl_bus_r_rdata;
  logic [NB_CTRLS-1:0]                  s_ctrl_bus_r_valid;
  logic [NB_CTRLS-1:0]                  s_ctrl_bus_r_opc;
  logic [NB_CTRLS-1:0][PE_ID_WIDTH-1:0] s_ctrl_bus_r_id;


  // MCHAN TCDM INIT --> TCDM MEMORY BUS SIGNALS
  logic [3:0][DATA_WIDTH-1:0] s_tcdm_bus_wdata;
  logic [3:0][ADDR_WIDTH-1:0] s_tcdm_bus_add;
  logic [3:0]                 s_tcdm_bus_req;
  logic [3:0]                 s_tcdm_bus_we_n; // "we_n" for write_enable_n
  logic [3:0][BE_WIDTH-1:0]   s_tcdm_bus_be;
  logic [3:0]                 s_tcdm_bus_gnt;
  logic [3:0][DATA_WIDTH-1:0] s_tcdm_bus_r_rdata;
  logic [3:0]                 s_tcdm_bus_r_valid;

  // CLUSTER CORE PORT BINDING
  generate
    for (genvar i=0; i<NB_CORES; i++) begin

     assign s_ctrl_bus_add[i]     = ctrl_slave[i].add[CTRL_ADD_WIDTH-1:0];
     assign s_ctrl_bus_req[i]     = ctrl_slave[i].req;
     assign s_ctrl_bus_wdata[i]   = ctrl_slave[i].wdata;
     assign s_ctrl_bus_we_n[i]     = ctrl_slave[i].we_n;    // "we_n" for write_enable_n
     assign s_ctrl_bus_be[i]      = ctrl_slave[i].be;
     assign s_ctrl_bus_id[i]      = i;

       
     assign ctrl_slave[i].gnt     = s_ctrl_bus_gnt[i];
     assign ctrl_slave[i].r_opc   = s_ctrl_bus_r_opc[i];
     assign ctrl_slave[i].r_valid = s_ctrl_bus_r_valid[i];
     assign ctrl_slave[i].r_rdata = s_ctrl_bus_r_rdata[i];

    end // for (genvar i=0; i<NB_CORES; i++)
  endgenerate

  // // CL CTRL PORT BINDING
  assign s_ctrl_bus_add[NB_CORES]     = cl_ctrl_slave.add[CTRL_ADD_WIDTH-1:0];
  assign s_ctrl_bus_req[NB_CORES]     = cl_ctrl_slave.req;
  assign s_ctrl_bus_wdata[NB_CORES]   = cl_ctrl_slave.wdata;
  assign s_ctrl_bus_we_n[NB_CORES]     = cl_ctrl_slave.we_n;
  assign s_ctrl_bus_be[NB_CORES]      = cl_ctrl_slave.be;
  assign s_ctrl_bus_id[NB_CORES]      = cl_ctrl_slave.id;
  assign cl_ctrl_slave.gnt     = s_ctrl_bus_gnt[NB_CORES];
  assign cl_ctrl_slave.r_opc   = s_ctrl_bus_r_opc[NB_CORES];
  assign cl_ctrl_slave.r_valid = s_ctrl_bus_r_valid[NB_CORES];
  assign cl_ctrl_slave.r_rdata = s_ctrl_bus_r_rdata[NB_CORES];
  assign cl_ctrl_slave.r_id    = s_ctrl_bus_r_id[NB_CORES];

  // FC CTRL PORT BINDING
  assign s_ctrl_bus_add[NB_CORES+1]     = fc_ctrl_slave.add[CTRL_ADD_WIDTH-1:0];
  assign s_ctrl_bus_req[NB_CORES+1]     = fc_ctrl_slave.req;
  assign s_ctrl_bus_wdata[NB_CORES+1]   = fc_ctrl_slave.wdata;
  assign s_ctrl_bus_we_n[NB_CORES+1]     = fc_ctrl_slave.we_n;
  assign s_ctrl_bus_be[NB_CORES+1]      = fc_ctrl_slave.be;
  assign s_ctrl_bus_id[NB_CORES+1]      = fc_ctrl_slave.id;
  assign fc_ctrl_slave.gnt     = s_ctrl_bus_gnt[NB_CORES+1];
  assign fc_ctrl_slave.r_opc   = s_ctrl_bus_r_opc[NB_CORES+1];
  assign fc_ctrl_slave.r_valid = s_ctrl_bus_r_valid[NB_CORES+1];
  assign fc_ctrl_slave.r_rdata = s_ctrl_bus_r_rdata[NB_CORES+1];
  assign fc_ctrl_slave.r_id    = s_ctrl_bus_r_id[NB_CORES+1];

  generate
    for (genvar i=0; i<4; i++) begin : TCDM_MASTER_BIND
      assign tcdm_master[i].add      = s_tcdm_bus_add[i];
      assign tcdm_master[i].req      = s_tcdm_bus_req[i];
      assign tcdm_master[i].data     = s_tcdm_bus_wdata[i];
      assign tcdm_master[i].we_n      = s_tcdm_bus_we_n[i];
      assign tcdm_master[i].be       = s_tcdm_bus_be[i];
      assign tcdm_master[i].boffs    = '0;
      assign tcdm_master[i].lrdy     = '1;

      assign s_tcdm_bus_gnt[i]       = tcdm_master[i].gnt;
      assign s_tcdm_bus_r_valid[i]   = tcdm_master[i].r_valid;
      assign s_tcdm_bus_r_rdata[i]   = tcdm_master[i].r_data;
    end
  endgenerate
   
  mchan #(

    .NB_CTRLS                 ( NB_CTRLS                     ),    // NUMBER OF CONTROL PORTS : 8 CORES, CL, FC
    //.NB_TRANSFERS             ( 16                    ),    // NUMBER OF AVAILABLE DMA CHANNELS
    //.CTRL_TRANS_QUEUE_DEPTH   ( 2                     ),    // DEPTH OF PRIVATE PER-CORE COMMAND QUEUE (CTRL_UNIT)
    //.GLOBAL_TRANS_QUEUE_DEPTH ( 8                     ),    // DEPTH OF GLOBAL COMMAND QUEUE (CTRL_UNIT)
     
    //.TCDM_ADD_WIDTH           ( TCDM_ADD_WIDTH        ),    // WIDTH OF TCDM ADDRESS
    //.EXT_ADD_WIDTH            ( 32                    ),    // WIDTH OF GLOBAL EXTERNAL ADDRESS
    //.NB_OUTSND_TRANS          ( 8                     ),    // NUMBER OF OUTSTANDING TRANSACTIONS
    //.MCHAN_BURST_LENGTH       ( 256                   ),    // ANY POWER OF 2 VALUE FROM 32 TO 2048
     
    //.AXI_ADDR_WIDTH           ( 32                    ),
    //.AXI_DATA_WIDTH           ( 64                    ),
    //.AXI_USER_WIDTH           ( 6                     ),
    //.AXI_ID_WIDTH             ( 4                     ),
     
    //.PE_ID_WIDTH              ( PE_ID_WIDTH           )
    //.NB_CORES                 ( NB_CORES              ),    // NUMBER OF CORES
    //.NB_TRANSFERS               ( 2*NB_CORES            ),
    .NB_TRANSFERS               ( (NB_CORES < 16) ? 2*NB_CORES : 16 ),
    //.CORE_TRANS_QUEUE_DEPTH   ( 2                     ),    // DEPTH OF PRIVATE PER-CORE COMMAND QUEUE (CTRL_UNIT)
    .GLOBAL_TRANS_QUEUE_DEPTH ( 2*NB_CORES            ),    // DEPTH OF GLOBAL COMMAND QUEUE (CTRL_UNIT)
    .TCDM_ADD_WIDTH           ( TCDM_ADD_WIDTH        ),    // WIDTH OF TCDM ADDRESS
    .EXT_ADD_WIDTH            ( AXI_ADDR_WIDTH        ),    // WIDTH OF GLOBAL EXTERNAL ADDRESS
    .NB_OUTSND_TRANS          ( NB_OUTSND_BURSTS      ),    // NUMBER OF OUTSTANDING TRANSACTIONS
    .MCHAN_BURST_LENGTH       ( MCHAN_BURST_LENGTH    ),    // ANY POWER OF 2 VALUE FROM 32 TO 2048
    .AXI_ADDR_WIDTH           ( AXI_ADDR_WIDTH        ),
    .AXI_DATA_WIDTH           ( AXI_DATA_WIDTH        ),
    .AXI_USER_WIDTH           ( AXI_USER_WIDTH        ),
    .AXI_ID_WIDTH             ( AXI_ID_WIDTH          ),
    .PE_ID_WIDTH              ( PE_ID_WIDTH           ),
    .CTRL_ADD_WIDTH           ( CTRL_ADD_WIDTH        )
  ) mchan_i (
    .i_clk                     ( i_clk                              ),
    .i_rst_n                   ( i_rst_n                            ),
    .i_scan_ckgt_enable        ( i_scan_ckgt_enable                 ),
    
    //.ctrl_pe_targ_req_i        (                                    ),
    //.ctrl_pe_targ_add_i        (                                    ),
    //.ctrl_pe_targ_type_i       (                                    ),
    //.ctrl_pe_targ_be_i         (                                    ),
    //.ctrl_pe_targ_data_i       (                                    ),
    //.ctrl_pe_targ_id_i         (                                    ),
    //.ctrl_pe_targ_gnt_o        (                                    ),
    //.ctrl_pe_targ_r_valid_o    (                                    ),
    //.ctrl_pe_targ_r_data_o     (                                    ),
    //.ctrl_pe_targ_r_opc_o      (                                    ),
    //.ctrl_pe_targ_r_id_o       (                                    ),
    
    .i_ctrl_targ_req           ( s_ctrl_bus_req                     ),
    .i_ctrl_targ_add           ( s_ctrl_bus_add                     ),
    .i_ctrl_targ_we_n          ( s_ctrl_bus_we_n                     ), // "we_n" for write_enable_n
    .i_ctrl_targ_be            ( s_ctrl_bus_be                      ),
    .i_ctrl_targ_data          ( s_ctrl_bus_wdata                   ),
    .i_ctrl_targ_id            ( s_ctrl_bus_id                      ),
    .o_ctrl_targ_gnt           ( s_ctrl_bus_gnt                     ),
    .o_ctrl_targ_r_opc         ( s_ctrl_bus_r_opc                   ),
    .o_ctrl_targ_r_id          ( s_ctrl_bus_r_id                    ),

    .o_ctrl_targ_r_valid       ( s_ctrl_bus_r_valid                 ),
    .o_ctrl_targ_r_data        ( s_ctrl_bus_r_rdata                 ),
    

    // TCDM INITIATOR
      //***************************************
    .o_tcdm_init_req           ( s_tcdm_bus_req                     ),
    .o_tcdm_init_add           ( s_tcdm_bus_add                     ),
    .o_tcdm_init_we_n          ( s_tcdm_bus_we_n                     ), // "we_n" for write_enable_n
    .o_tcdm_init_be            ( s_tcdm_bus_be                      ),
    .o_tcdm_init_data          ( s_tcdm_bus_wdata                   ),
    .o_tcdm_init_sid           (                                    ),
    .i_tcdm_init_gnt           ( s_tcdm_bus_gnt                     ),
    .i_tcdm_init_r_valid       ( s_tcdm_bus_r_valid                 ),
    .i_tcdm_init_r_data        ( s_tcdm_bus_r_rdata                 ),

    // EXTERNAL INITIATOR
    //***************************************

    .o_axi_master_aw_valid     ( ext_master.aw_valid                ),
    .o_axi_master_aw_addr      ( ext_master.aw_addr                 ),
    .o_axi_master_aw_prot      ( ext_master.aw_prot                 ),
    .o_axi_master_aw_region    ( ext_master.aw_region               ),
    .o_axi_master_aw_len       ( ext_master.aw_len                  ),
    .o_axi_master_aw_size      ( ext_master.aw_size                 ),
    .o_axi_master_aw_burst     ( ext_master.aw_burst                ),
    .o_axi_master_aw_lock      ( ext_master.aw_lock                 ),
    .o_axi_master_aw_cache     ( ext_master.aw_cache                ),
    .o_axi_master_aw_qos       ( ext_master.aw_qos                  ),
    .o_axi_master_aw_id        ( ext_master.aw_id[AXI_ID_WIDTH-1:0] ),
    .o_axi_master_aw_user      ( ext_master.aw_user                 ),
    .i_axi_master_aw_ready     ( ext_master.aw_ready                ),

    .o_axi_master_ar_valid     ( ext_master.ar_valid                ),
    .o_axi_master_ar_addr      ( ext_master.ar_addr                 ),
    .o_axi_master_ar_prot      ( ext_master.ar_prot                 ),
    .o_axi_master_ar_region    ( ext_master.ar_region               ),
    .o_axi_master_ar_len       ( ext_master.ar_len                  ),
    .o_axi_master_ar_size      ( ext_master.ar_size                 ),
    .o_axi_master_ar_burst     ( ext_master.ar_burst                ),
    .o_axi_master_ar_lock      ( ext_master.ar_lock                 ),
    .o_axi_master_ar_cache     ( ext_master.ar_cache                ),
    .o_axi_master_ar_qos       ( ext_master.ar_qos                  ),
    .o_axi_master_ar_id        ( ext_master.ar_id[AXI_ID_WIDTH-1:0] ),
    .o_axi_master_ar_user      ( ext_master.ar_user                 ),
    .i_axi_master_ar_ready     ( ext_master.ar_ready                ),

    .o_axi_master_w_valid      ( ext_master.w_valid                 ),
    .o_axi_master_w_data       ( ext_master.w_data                  ),
    .o_axi_master_w_strb       ( ext_master.w_strb                  ),
    .o_axi_master_w_user       ( ext_master.w_user                  ),
    .o_axi_master_w_last       ( ext_master.w_last                  ),
    .i_axi_master_w_ready      ( ext_master.w_ready                 ),

    .i_axi_master_r_valid      ( ext_master.r_valid                 ),
    .i_axi_master_r_data       ( ext_master.r_data                  ),
    .i_axi_master_r_resp       ( ext_master.r_resp                  ),
    .i_axi_master_r_last       ( ext_master.r_last                  ),
    .i_axi_master_r_id         ( ext_master.r_id[AXI_ID_WIDTH-1:0]  ),
    .i_axi_master_r_user       ( ext_master.r_user                  ),
    .o_axi_master_r_ready      ( ext_master.r_ready                 ),

    .i_axi_master_b_valid      ( ext_master.b_valid                 ),
    .i_axi_master_b_resp       ( ext_master.b_resp                  ),
    .i_axi_master_b_id         ( ext_master.b_id[AXI_ID_WIDTH-1:0]  ),
    .i_axi_master_b_user       ( ext_master.b_user                  ),
    .o_axi_master_b_ready      ( ext_master.b_ready                 ),

    .o_term_evt                ( {o_term_event_pe,o_term_event_cl,o_term_event}     ),
    .o_term_int                ( {o_term_irq_pe,o_term_irq_cl,o_term_irq      }     ),

    .o_busy                    ( o_busy                             )
  );

  assign ext_master.aw_atop = '0; // Fix LINT issue

endmodule
