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
 * core_region.sv
 * Davide Rossi <davide.rossi@unibo.it>
 * Antonio Pullini <pullinia@iis.ee.ethz.ch>
 * Igor Loi <igor.loi@unibo.it>
 * Francesco Conti <fconti@iis.ee.ethz.ch>
 */


module core_region
#(
  // CORE PARAMETERS
  parameter NB_CORES               = 8,
  parameter N_EXT_PERF_COUNTERS    = 1,
  parameter CORE_ID                = 0,
  parameter ADDR_WIDTH             = 32,
  parameter DATA_WIDTH             = 32,
  parameter INSTR_RDATA_WIDTH      = 32,
  parameter CLUSTER_ALIAS          = 1,
  parameter CLUSTER_ALIAS_BASE     = 12'h000,
  parameter REMAP_ADDRESS          = 0,

  parameter APU_NARGS_CPU          = 2,
  parameter APU_WOP_CPU            = 1,
  parameter WAPUTYPE               = 3,
  parameter APU_NDSFLAGS_CPU       = 3,
  parameter APU_NUSFLAGS_CPU       = 5,

  parameter FPU                    =  0,
  parameter FPU_ADDMUL_LAT         =  0,
  parameter FPU_OTHERS_LAT         =  0,
  parameter FP_DIVSQRT             =  0,
  parameter SHARED_FP              =  0,
  parameter SHARED_FP_DIVSQRT      =  0,

  parameter DATA_MISS              =  0,
  parameter DUMP_INSTR_FETCH       =  0,
  parameter DEBUG_FETCH_INTERFACE  =  0,

  parameter DEBUG_START_ADDR       = 32'h1A11_0000,

  parameter L2_SLM_FILE            = "./slm_files/l2_stim.slm",
  parameter ROM_SLM_FILE           = "../sw/apps/boot/slm_files/l2_stim.slm"
)
(
  input logic                            clk_i,
  input logic                            rst_ni,

  input logic [9:0]                      base_addr_i, // FOR CLUSTER VIRTUALIZATION

  input logic [5:0]                      cluster_id_i,

  input logic                            irq_req_i,
  output logic                           irq_ack_o,
  input logic [4:0]                      irq_id_i,
  output logic [4:0]                     irq_ack_id_o,

  input logic                            clock_en_i,
  input logic                            fetch_en_i,
  input logic                            fregfile_disable_i,

  input logic [31:0]                     boot_addr_i,
  input logic                            debug_req_i,
  input logic [31:0]                     dm_halt_addr_i,
  input logic [31:0]                     dm_exception_addr_i,

  input logic                            scan_cg_en_i,

  output logic                           core_busy_o,

  // Interface to Instruction Logarithmic interconnect (Req->grant handshake)
  output logic                           instr_req_o,
  input logic                            instr_gnt_i,
  output logic [31:0]                    instr_addr_o,
  input logic [INSTR_RDATA_WIDTH-1:0]    instr_r_rdata_i,
  input logic                            instr_r_valid_i,

  //XBAR_TCDM_BUS.Slave     debug_bus,
  //output logic            debug_core_halted_o,
  //input logic             debug_core_halt_i,
  //input logic             debug_core_resume_i,

  // Interface for DEMUX to TCDM INTERCONNECT ,PERIPHERAL INTERCONNECT and DMA CONTROLLER
  hci_core_intf.master                   tcdm_data_master,
  XBAR_TCDM_BUS.Master                   dma_ctrl_master,
  XBAR_PERIPH_BUS.Master                 eu_ctrl_master,
  XBAR_PERIPH_BUS.Master                 periph_data_master,

  // Interface for Shared FPU cluster
  output logic                           apu_master_req_o,
  input logic                            apu_master_gnt_i,
  // request channel
  output logic [WAPUTYPE-1:0]            apu_master_type_o,
  output logic [APU_NARGS_CPU-1:0][31:0] apu_master_operands_o,
  output logic [APU_WOP_CPU-1:0]         apu_master_op_o,
  output logic [APU_NDSFLAGS_CPU-1:0]    apu_master_flags_o,
  // response channel
  output logic                           apu_master_ready_o,
  input logic                            apu_master_valid_i,
  input logic [31:0]                     apu_master_result_i,
  input logic [APU_NUSFLAGS_CPU-1:0]     apu_master_flags_i

);

  import cv32e40p_fpu_pkg::*;


  //********************************************************
  //***************** SIGNALS DECLARATION ******************
  //********************************************************

  XBAR_DEMUX_BUS    s_core_bus();         // Internal interface between CORE       <--> DEMUX
  XBAR_PERIPH_BUS#(.ID_WIDTH(NB_CORES+1))   periph_demux_bus();   // Internal interface between CORE_DEMUX <--> PERIPHERAL DEMUX

  logic [4:0]      perf_counters;
  logic            clk_int;
  logic [31:0]     hart_id;
  logic            core_sleep;
  logic [31:0]     core_irq_x;

  logic            core_instr_req;
  logic            core_instr_gnt;
  logic [31:0]     core_instr_addr;
  logic [31:0]     core_instr_r_rdata;
  logic            core_instr_r_valid;

  logic            core_data_req;

  logic            obi_instr_req;
  logic            pulp_instr_req;

  // clock gate of the core_region less the core itself
  clkgating clock_gate_i
  (
   .i_clk       ( clk_i              ),
   .i_test_mode ( scan_cg_en_i       ),
   .i_enable    ( clock_en_i         ),
   .o_gated_clk ( clk_int            )
  );

  assign hart_id = {21'b0, cluster_id_i[5:0], 1'b0, CORE_ID[3:0]};

  //********************************************************
  //***************** PROCESSOR ****************************
  //********************************************************

  cv32e40p_core #(
    .COREV_PULP          ( 1                 ),
    .COREV_CLUSTER       ( 1                 ),
    .FPU                 ( FPU               ),
    .FPU_ADDMUL_LAT      ( FPU_ADDMUL_LAT    ),
    .FPU_OTHERS_LAT      ( FPU_OTHERS_LAT    ),
    .ZFINX               ( FPU ? 1 : 0       ),
    .NUM_MHPMCOUNTERS    ( 1                 )
  )
   RISCV_CORE
  (
    .clk_i                 ( clk_i                    ),
    .rst_ni                ( rst_ni                   ),

    .pulp_clock_en_i       ( clock_en_i               ),
    .scan_cg_en_i          ( scan_cg_en_i             ),

    .boot_addr_i           ( boot_addr_i              ),
    .mtvec_addr_i          ( boot_addr_i              ), // Fixed : LINT issue
    .hart_id_i             ( hart_id                  ),
    .dm_halt_addr_i        ( dm_halt_addr_i           ),
    .dm_exception_addr_i   ( dm_exception_addr_i      ), // LINT issue

    .instr_addr_o          ( instr_addr_o             ),
    .instr_req_o           ( obi_instr_req            ),
    .instr_rdata_i         ( instr_r_rdata_i          ),
    .instr_gnt_i           ( instr_gnt_i              ),
    .instr_rvalid_i        ( instr_r_valid_i          ),

    .data_addr_o           ( s_core_bus.add           ),
    .data_wdata_o          ( s_core_bus.wdata         ),
    .data_we_o             ( s_core_bus.we            ),
    .data_req_o            ( core_data_req            ),
    .data_be_o             ( s_core_bus.be            ),
    .data_rdata_i          ( s_core_bus.r_rdata       ),
    .data_gnt_i            ( s_core_bus.gnt           ),
    .data_rvalid_i         ( s_core_bus.r_valid       ),

    .irq_i                 ( core_irq_x               ), // New interface with 32 physical lines (one-hot)
    .irq_id_o              ( irq_ack_id_o             ), // New interface with 32 lines
    .irq_ack_o             ( irq_ack_o                ),

    .debug_req_i           ( debug_req_i              ),

    .fetch_enable_i        ( fetch_en_i               ),
    .core_sleep_o          ( core_sleep               ),


     // apu-interconnect
    .apu_req_o      ( apu_master_req_o      ),
    .apu_gnt_i      ( apu_master_gnt_i      ),
    .apu_operands_o ( apu_master_operands_o ),
    .apu_op_o       ( apu_master_op_o       ),
    .apu_flags_o    ( apu_master_flags_o    ),

    .apu_rvalid_i   ( apu_master_valid_i    ),
    .apu_result_i   ( apu_master_result_i   ),
    .apu_flags_i    ( apu_master_flags_i    )
  );

  assign core_busy_o = ~core_sleep;

  // OBI-PULP adapter
  obi_pulp_adapter i_obi_pulp_adapter_instr (
    .rst_ni(rst_ni),
    .clk_i(clk_i),
    .core_req_i(obi_instr_req),
    .mem_gnt_i(instr_gnt_i),
    .mem_rvalid_i(instr_r_valid_i),
    .mem_req_o(pulp_instr_req)
  );

  assign instr_req_o = pulp_instr_req;

  obi_pulp_adapter i_obi_pulp_adapter_data (
    .rst_ni(rst_ni),
    .clk_i(clk_i),
    .core_req_i(core_data_req),
    .mem_gnt_i(s_core_bus.gnt),
    .mem_rvalid_i(s_core_bus.r_valid),
    .mem_req_o(s_core_bus.req)
  );

  // CV32E40P supports 32 additional fast interrupts and reads the interrupt lines directly.
  // Convert ID back to interrupt lines
  always_comb begin : gen_core_irq_x
    core_irq_x = '0;
    if (irq_req_i) begin
        core_irq_x[irq_id_i] = 1'b1;
    end
  end

  assign apu_master_ready_o = 1'b1;

  // Generate APU FPU type (not generated anymore by CV32E40P)
  assign apu_master_type_o = (apu_master_op_o == DIV || apu_master_op_o == SQRT) ? 1 : 0;

  //assign debug_bus.r_opc = 1'b0;

  // Bind to 0 Unused Signals in CORE interface
  assign s_core_bus.r_gnt       = 1'b0;
  assign s_core_bus.barrier     = 1'b0;
  assign s_core_bus.exec_cancel = 1'b0;
  assign s_core_bus.exec_stall  = 1'b0;

  // Performance Counters
  assign perf_counters[4] = tcdm_data_master.req & (~tcdm_data_master.gnt);  // Cycles lost due to contention


  //********************************************************
  //****** DEMUX TO TCDM AND PERIPHERAL INTERCONNECT *******
  //********************************************************

  // demuxes to TCDM & memory hierarchy
  core_demux #(
    .PERF_CNT           ( 0                  ),
    .ADDR_WIDTH         ( 32                 ),
    .DATA_WIDTH         ( 32                 ),
    .BYTE_ENABLE_BIT    ( DATA_WIDTH/8       ),
    .REMAP_ADDRESS      ( REMAP_ADDRESS      ),
    .CLUSTER_ALIAS      ( CLUSTER_ALIAS      ),
    .CLUSTER_ALIAS_BASE ( CLUSTER_ALIAS_BASE )
  ) core_demux_i (
    .clk                (  clk_int                    ),
    .rst_ni             (  rst_ni                     ),
    .test_en_i          (  scan_cg_en_i               ),
    .base_addr_i        (  base_addr_i                ),
    .data_req_i         (  s_core_bus.req             ),
    .data_add_i         (  s_core_bus.add             ),
    .data_we_n_i         ( ~s_core_bus.we              ), //inverted when using OR10N
    .data_wdata_i       (  s_core_bus.wdata           ),
    .data_be_i          (  s_core_bus.be              ),
    .data_gnt_o         (  s_core_bus.gnt             ),
    .data_r_gnt_i       (  s_core_bus.r_gnt           ),
    .data_r_valid_o     (  s_core_bus.r_valid         ),
    .data_r_opc_o       (                             ),
    .data_r_rdata_o     (  s_core_bus.r_rdata         ),

    .data_req_o_SH      (  tcdm_data_master.req       ),
    .data_add_o_SH      (  tcdm_data_master.add       ),
    .data_we_n_o_SH      (  tcdm_data_master.we_n       ),
    .data_wdata_o_SH    (  tcdm_data_master.data      ),
    .data_be_o_SH       (  tcdm_data_master.be        ),
    .data_gnt_i_SH      (  tcdm_data_master.gnt       ),
    .data_r_valid_i_SH  (  tcdm_data_master.r_valid   ),
    .data_r_rdata_i_SH  (  tcdm_data_master.r_data    ),

    .data_req_o_EXT     (  periph_demux_bus.req         ),
    .data_add_o_EXT     (  periph_demux_bus.add         ),
    .data_we_n_o_EXT     (  periph_demux_bus.we_n         ),
    .data_wdata_o_EXT   (  periph_demux_bus.wdata       ),
    .data_be_o_EXT      (  periph_demux_bus.be          ),
    .data_gnt_i_EXT     (  periph_demux_bus.gnt         ),
    .data_r_valid_i_EXT (  periph_demux_bus.r_valid     ),
    .data_r_rdata_i_EXT (  periph_demux_bus.r_rdata     ),
    .data_r_opc_i_EXT   (  periph_demux_bus.r_opc       ),

    .data_req_o_PE      (  periph_data_master.req     ),
    .data_add_o_PE      (  periph_data_master.add     ),
    .data_we_n_o_PE      (  periph_data_master.we_n     ),
    .data_wdata_o_PE    (  periph_data_master.wdata   ),
    .data_be_o_PE       (  periph_data_master.be      ),
    .data_gnt_i_PE      (  periph_data_master.gnt     ),
    .data_r_valid_i_PE  (  periph_data_master.r_valid ),
    .data_r_rdata_i_PE  (  periph_data_master.r_rdata ),
    .data_r_opc_i_PE    (  periph_data_master.r_opc   ),

    .perf_l2_ld_o       (  perf_counters[0]           ),
    .perf_l2_st_o       (  perf_counters[1]           ),
    .perf_l2_ld_cyc_o   (  perf_counters[2]           ),
    .perf_l2_st_cyc_o   (  perf_counters[3]           )
  );

  assign tcdm_data_master.boffs = '0;
  assign tcdm_data_master.lrdy  = '1;
  assign tcdm_data_master.user  = '0;
  assign periph_data_master.id  = '0;

   periph_demux periph_demux_i (
     .clk               ( clk_int                  ),
     .rst_ni            ( rst_ni                   ),

     .data_req_i        ( periph_demux_bus.req     ),
     .data_add_i        ( periph_demux_bus.add     ),
     .data_we_n_i        ( periph_demux_bus.we_n     ),
     .data_wdata_i      ( periph_demux_bus.wdata   ),
     .data_be_i         ( periph_demux_bus.be      ),
     .data_gnt_o        ( periph_demux_bus.gnt     ),

     .data_r_valid_o    ( periph_demux_bus.r_valid ),
     .data_r_opc_o      ( periph_demux_bus.r_opc   ),
     .data_r_rdata_o    ( periph_demux_bus.r_rdata ),

     .data_req_o_MH     ( dma_ctrl_master.req      ),
     .data_add_o_MH     ( dma_ctrl_master.add      ),
     .data_we_n_o_MH     ( dma_ctrl_master.we_n      ),
     .data_wdata_o_MH   ( dma_ctrl_master.wdata    ),
     .data_be_o_MH      ( dma_ctrl_master.be       ),
     .data_gnt_i_MH     ( dma_ctrl_master.gnt      ),

     .data_r_valid_i_MH ( dma_ctrl_master.r_valid  ),
     .data_r_rdata_i_MH ( dma_ctrl_master.r_rdata  ),
     .data_r_opc_i_MH   ( dma_ctrl_master.r_opc    ),

     .data_req_o_EU     ( eu_ctrl_master.req       ),
     .data_add_o_EU     ( eu_ctrl_master.add       ),
     .data_we_n_o_EU     ( eu_ctrl_master.we_n       ),
     .data_wdata_o_EU   ( eu_ctrl_master.wdata     ),
     .data_be_o_EU      ( eu_ctrl_master.be        ),
     .data_gnt_i_EU     ( eu_ctrl_master.gnt       ),

     .data_r_valid_i_EU ( eu_ctrl_master.r_valid   ),
     .data_r_rdata_i_EU ( eu_ctrl_master.r_rdata   ),
     .data_r_opc_i_EU   ( eu_ctrl_master.r_opc     )
    );

  assign eu_ctrl_master.id  = '0;


  /* debug stuff */
  //synopsys translate_off



  // CHECK IF THE CORE --> LS port is makin accesses in unmapped regions
generate
  if (!CLUSTER_ALIAS) begin : g_accesses_unmapped_regions_no_alias
  always @(posedge clk_i)
  begin : CHECK_ASSERTIONS
    if ((s_core_bus.req == 1'b1) && (s_core_bus.add < 32'h1000_0000)) begin
      $error("ERROR_1 (0x00000000 -> 0x10000000) : Data interface is making a request on unmapped region --> %8x\t at time %t [ns]" ,s_core_bus.add, $time()/1000 );
      $finish();
    end

    if ((s_core_bus.req == 1'b1) && (s_core_bus.add >= 32'h1040_0000) && ((s_core_bus.add < 32'h1A00_0000))) begin
      $error("ERROR_2 (0x10400000 -> 0x1A000000) : Data interface is making a request on unmapped region --> %8x\t at time %t [ns]" ,s_core_bus.add, $time()/1000 );
      $finish();
    end
  end
  end
endgenerate


  // COMPARE THE output of the instruction CACHE with the slm files generated by the compiler
generate

  if (DEBUG_FETCH_INTERFACE) begin : g_debug_fetch_interface_comp
    integer FILE;
    string  FILENAME;
    string  FILE_ID;

    logic                         instr_gnt_L2;
    logic                         instr_gnt_ROM;
    logic [INSTR_RDATA_WIDTH-1:0] instr_r_rdata_ROM;
    logic                         instr_r_valid_ROM;
    logic [INSTR_RDATA_WIDTH-1:0] instr_r_rdata_L2;
    logic                         instr_r_valid_L2;
    logic                         destination; //--> 0 fetch from BOOT_ROM, 1--> fetch from L2_MEMORY

    initial
    begin
      FILE_ID.itoa(CORE_ID);
      FILENAME = {"FETCH_CORE_", FILE_ID, ".log" };
      FILE=$fopen(FILENAME,"w");
    end

    // BOOT code is loaded in this dummy ROM_MEMORY
    /*  -----\/----- EXCLUDED -----\/-----
    generate
      case(INSTR_RDATA_WIDTH)
        128: begin
          ibus_lint_memory_128 #(
            .addr_width    ( 16           ),
            .INIT_MEM_FILE ( ROM_SLM_FILE )
          ) ROM_MEMORY (
            .clk            ( clk_i              ),
            .rst_n          ( rst_ni             ),
            .lint_req_i     ( instr_req_o        ),
            .lint_grant_o   ( instr_gnt_ROM      ),
            .lint_addr_i    ( instr_addr_o[19:4] ), //instr_addr_o[17:2]   --> 2^17 bytes max program
            .lint_r_rdata_o ( instr_r_rdata_ROM  ),
            .lint_r_valid_o ( instr_r_valid_ROM  )
          );

          // application code is loaded in this dummy L2_MEMORY
          ibus_lint_memory_128 #(
            .addr_width    ( 16          ),
            .INIT_MEM_FILE ( L2_SLM_FILE )
          ) L2_MEMORY (
            .clk            ( clk_i              ),
            .rst_n          ( rst_ni             ),
            .lint_req_i     ( instr_req_o        ),
            .lint_grant_o   ( instr_gnt_L2       ),
            .lint_addr_i    ( instr_addr_o[19:4] ), //instr_addr_o[17:2]    --> 2^17 bytes max program
            .lint_r_rdata_o ( instr_r_rdata_L2   ),
            .lint_r_valid_o ( instr_r_valid_L2   )
          );
        end
        32: begin
          ibus_lint_memory #(
            .addr_width      ( 16              ),
            .INIT_MEM_FILE   ( ROM_SLM_FILE    )
          ) ROM_MEMORY (
            .clk             ( clk_i              ),
            .rst_n           ( rst_ni             ),
            .lint_req_i      ( instr_req_o        ),
            .lint_grant_o    ( instr_gnt_ROM      ),
            .lint_addr_i     ( instr_addr_o[17:2] ), //instr_addr_o[17:2]   --> 2^17 bytes max program
            .lint_r_rdata_o  ( instr_r_rdata_ROM  ),
            .lint_r_valid_o  ( instr_r_valid_ROM  )
          );

          // application code is loaded in this dummy L2_MEMORY
          ibus_lint_memory #(
            .addr_width      ( 16                 ),
            .INIT_MEM_FILE   ( L2_SLM_FILE        )
          ) L2_MEMORY (
            .clk             ( clk_i              ),
            .rst_n           ( rst_ni             ),
            .lint_req_i      ( instr_req_o        ),
            .lint_grant_o    ( instr_gnt_L2       ),
            .lint_addr_i     ( instr_addr_o[17:2] ), //instr_addr_o[17:2]    --> 2^17 bytes max program
            .lint_r_rdata_o  ( instr_r_rdata_L2   ),
            .lint_r_valid_o  ( instr_r_valid_L2   )
          );
        end
      endcase // INSTR_RDATA_WIDTH
    endgenerate
    -----/\----- EXCLUDED -----/\----- */

    // SELF CHECK ROUTINES TO compare instruction fetches with slm files
    always_ff @(posedge clk_i)
    begin
      if(instr_r_valid_i) begin
        $fwrite( FILE , "\t --> %8h\n",instr_r_rdata_i);
        case(destination)
          1'b1: begin
            // Not active by default as it is wrong once the code is dynamically modified
            //if(instr_r_rdata_i !== instr_r_rdata_L2)
            //begin
            //  $warning("Error DURING L2 fetch: %x != %x", instr_r_rdata_i, instr_r_rdata_L2);
            //  $stop();
            //end
          end
          1'b0: begin
            if(instr_r_rdata_i !== instr_r_rdata_ROM) begin
              $warning("Error DURING ROM Fetch: %x != %x", instr_r_rdata_i, instr_r_rdata_ROM);
              $stop();
            end
          end
        endcase
      end
      //DUMP TO FILE every transaction to instruction cache
      if(instr_req_o & instr_gnt_i) begin
        if(instr_addr_o[31:24] == 8'h1A)
          destination <= 1'b0;
        else
          destination <= 1'b1;
          if (DUMP_INSTR_FETCH) begin
              $fwrite( FILE , "%t [ns]: FETCH at address %8h",$time/1000, instr_addr_o);
          end
      end
    end
end
endgenerate

generate
  if (DATA_MISS) begin : g_data_miss
    logic data_hit;
    logic req;
  end
endgenerate

  logic reg_cache_refill;

  always_ff @(posedge clk_i , negedge rst_ni)
  begin
    if ( rst_ni == 1'b0 ) begin
      reg_cache_refill <= 1'b0;
    end
    else begin
      if (instr_req_o)
        reg_cache_refill <= 1'b1;
      else if(instr_r_valid_i && !instr_req_o)
        reg_cache_refill <= 1'b0;
    end
  end
//synopsys translate_on

endmodule
