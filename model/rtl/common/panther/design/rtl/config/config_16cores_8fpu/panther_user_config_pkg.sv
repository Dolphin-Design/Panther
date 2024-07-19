`ifndef PANTHER_USER_CONFIG_PKG
`define PANTHER_USER_CONFIG_PKG


package panther_user_config_pkg;

  // Cluster parameters
  /*
   * NB_CORES 4|8|16
   */
  parameter int NB_CORES                    = 16          ;

  // Cores and FPU parameters
  /*
   * ROM_BOOT_ADDR (32 bit address)
   */
  parameter int ROM_BOOT_ADDR               = 32'h1A000000;
  /*
   * BOOT_ADDR (32 bit address)
   */
  parameter int BOOT_ADDR                   = 32'h1C000080;
  /*
   * Debug Address
   * DM_HALT_ADDR (32 bit address)
   */
  parameter int DM_HALT_ADDR                = 32'h1A110800;
  /*
   * Debug Exception Address
   * DM_EXCEPTION_ADDR (32 bit address)
   */
  parameter int DM_EXCEPTION_ADDR           = 32'h1A110000;
  /*
   * Floating Point Unit enable
   * FPU 0|1
   */
  parameter bit FPU                         = 1           ;
  /*
   * FPU Pipeline registers 0|1|2
   *   ADDition/MULtiplication computing lane pipeline registers number
   *   COMParison/CONVersion computing lanes pipeline registers number
   */
  parameter int FPU_ADDMUL_LAT              = 1           ;
  parameter int FPU_OTHERS_LAT              = 1           ;

  // TCDM and log interconnect parameters
  /*
   * TCDM_SIZE 32|64|128|256 (value in kilobytes)
   */
  parameter int TCDM_SIZE_KB                = 256         ;
  /*
   * NB_TCDM_BANKS = (NB_CORES == 16) ? 32 : 16 ;
   * ADDR_WIDTH    = 32
   * BE_WIDTH      = 4
   * DATA_WIDTH    = 32
   */

  // Shared Instruction Cache parameters
  /*
   * ICACHE_SIZE 4|8|16|32 (value in kilobytes)
   */
  parameter int ICACHE_SIZE_KB              = 32          ;
  /*
   * USE_REDUCED_TAG 0|1
   *   To reduce I$ tag width to log2(L2_SIZE*1024) in tag memories
   */
  parameter bit USE_REDUCED_TAG             = 1           ;
  /*
   * L2_SIZE (value in power of two kilobytes)
   */
  parameter int L2_SIZE_KB                  = 256         ;
  /*
   * ICACHE_STAT 0|1
   */
  parameter bit ICACHE_STAT                 = 1           ;
  /*
   * PRI_NB_WAYS        = 2
   * PRI_TAG_ADDR_WIDTH = 4
   * PRI_TAG_WIDTH      = (USE_REDUCED_TAG == 1) ? $clog2(L2_SIZE/512)+2 : 26
   * PRI_DATA_WIDTH     = 128
   * SH_NB_BANKS        = (NB_CORES == 4) ? 2 : NB_CORES/4
   * SH_TAG_ADDR_WIDTH  = $clog2(SH_CACHE_SIZE/SH_NB_BANKS) - 6
   * SH_NB_WAYS         = 4
   * SH_TAG_DATA_WIDTH  = (USE_REDUCED_TAG == 1) ? ( $clog2(L2_SIZE) - $clog(ICACHE_SIZE/SH_NB_BANKS) - $clog2(SH_NB_BANKS) -7) : (28 - $clog2(SH_NB_BANKS) - SH_TAG_ADDR_WIDTH + 1)
   * SH_DATA_ADDR_WIDTH = $clog2(SH_DATA_NB_ROWS)
   * SH_DATA_BE_WIDTH   = SH_DATA_DATA_WIDTH/8
   * SH_DATA_DATA_WIDTH = 128
   */

  // AXI parameters
  /*
   * AXI interfaces synchronized or not
   * AXI_SYNCH_INTERF 0|1
   */
  parameter bit AXI_SYNCH_INTERF            = 1           ;
  /*
   * AXI Master Shared Instruction Cache interface merged with Data/DMA one or not
   * USE_DEDICATED_INSTR_IF 0|1
   */
  parameter bit USE_DEDICATED_INSTR_IF      = 0           ;
  /*
   * AXI Master Shared Instruction Cache interface data width
   * AXI_INSTR_WIDTH 32|64
   */
  parameter int AXI_INSTR_WIDTH             = 32          ;
  /*
   * AXI Master interface data width
   * AXI_DATA_C2S_WIDTH 32|64
   */
  parameter int AXI_DATA_C2S_WIDTH          = 32          ;
  /*
   * AXI Slave interface data width
   * AXI_DATA_S2C_WIDTH 32|64
   */
  parameter int AXI_DATA_S2C_WIDTH          = 32          ;
  /*
   * AXI interfaces User field width
   * AXI_USER_WIDTH
   */
  parameter int AXI_USER_WIDTH              = 4           ;
  /*
   * AXI Slave interfaces Id field width (must be at least 7)
   * AXI_ID_WIDTH
   */
  parameter int AXI_ID_IN_WIDTH             = 7           ;
  /*
   * AXI_ADDR_WIDTH       = 32
   * AXI_ID_OUT_WIDTH     = 7
   * AXI_ID_IC_WIDTH      = (USE_DEDICATED_INSTR_IF)?((NB_CORES == 16) ? 3 : 2) : AXI_ID_IN_WIDTH
   * AXI_STRB_S2C_WIDTH   = AXI_DATA_S2C_WIDTH/8
   * AXI_STRB_C2S_WIDTH   = AXI_DATA_C2S_WIDTH/8
   * AXI_STRB_INSTR_WIDTH = AXI_INSTR_WIDTH/8
   */

  // Events parameter
  // Size of the event bus
  parameter int EVNT_WIDTH                  = 8           ;

endpackage

`endif
