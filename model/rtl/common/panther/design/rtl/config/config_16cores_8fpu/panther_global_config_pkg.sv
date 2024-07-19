`ifndef PANTHER_GLOBAL_CONFIG_PKG
`define PANTHER_GLOBAL_CONFIG_PKG


package panther_global_config_pkg;

  import panther_user_config_pkg::ROM_BOOT_ADDR          ;
  import panther_user_config_pkg::BOOT_ADDR              ;
  import panther_user_config_pkg::DM_HALT_ADDR           ;
  import panther_user_config_pkg::DM_EXCEPTION_ADDR      ;
  import panther_user_config_pkg::FPU_ADDMUL_LAT         ;
  import panther_user_config_pkg::FPU_OTHERS_LAT         ;
  import panther_user_config_pkg::TCDM_SIZE_KB           ;
  import panther_user_config_pkg::ICACHE_SIZE_KB         ;
  import panther_user_config_pkg::L2_SIZE_KB             ;
  import panther_user_config_pkg::USE_REDUCED_TAG        ;
  import panther_user_config_pkg::ICACHE_STAT            ;
  import panther_user_config_pkg::AXI_SYNCH_INTERF       ;
  import panther_user_config_pkg::USE_DEDICATED_INSTR_IF ;
  import panther_user_config_pkg::AXI_INSTR_WIDTH        ;
  import panther_user_config_pkg::AXI_DATA_C2S_WIDTH     ;
  import panther_user_config_pkg::AXI_DATA_S2C_WIDTH     ;
  import panther_user_config_pkg::AXI_USER_WIDTH         ;
  import panther_user_config_pkg::AXI_ID_IN_WIDTH        ;
  import panther_user_config_pkg::EVNT_WIDTH             ;
  export panther_user_config_pkg::*                      ;

  import panther_user_config_pkg::NB_CORES               ;
  import panther_user_config_pkg::FPU                    ;
  export panther_user_config_pkg::*                      ;

  /*
   * CLUSTER_ALIAS 0|1
   */
  parameter bit CLUSTER_ALIAS               = 1           ;
  /*
   * CLUSTER_ALIAS_BASE (12bits offset)
   */
  parameter int CLUSTER_ALIAS_BASE          = 12'h000     ;
  /*
   * REMAP_ADDRESS 0|1
   */
  parameter bit REMAP_ADDRESS               = 0           ; // for Cluster virtualization

  // Core parameters
  parameter int INSTR_RDATA_WIDTH                         = 32                             ;

  // FPU PARAMETERS
  parameter int APU_NARGS_CPU                             = 3                              ;
  parameter int APU_WOP_CPU                               = 6                              ;
  parameter int WAPUTYPE                                  = 3                              ;
  parameter int APU_NDSFLAGS_CPU                          = 15                             ;
  parameter int APU_NUSFLAGS_CPU                          = 5                              ;
  parameter bit SHARED_FPU_CLUSTER                        = FPU                            ;
  parameter int CLUST_FP_DIVSQRT                          = 1                              ;
  parameter int CLUST_SHARED_FP                           = 2                              ;
  parameter int CLUST_SHARED_FP_DIVSQRT                   = 2                              ;

  // AXI parameters
  parameter int AXI_ADDR_WIDTH                            = 32                             ;
  parameter int AXI_STRB_INSTR_WIDTH                      = AXI_INSTR_WIDTH/8              ;
  parameter int AXI_STRB_C2S_WIDTH                        = AXI_DATA_C2S_WIDTH/8           ;
  parameter int AXI_STRB_S2C_WIDTH                        = AXI_DATA_S2C_WIDTH/8           ;
  parameter int AXI_ID_OUT_WIDTH                          = 7                              ;
  parameter int AXI4_REGION_MAP_SIZE                      = 4                              ;

  // number of DMA TCDM plugs, NOT number of DMA slave peripherals!
  // Everything will go to hell if you change this!
  parameter int NB_DMAS                                  = 4                               ;

  // Hardware Processing Element parameters
  parameter int HWPE_PRESENT                             = 0                               ; // set to 1 if HW Processing Engines are present in the cluster
  parameter int USE_HETEROGENEOUS_INTERCONNECT           = 0                               ; // set to 1 to connect HWPEs via heterogeneous interconnect; to 0 for larger LIC
  parameter int NB_HWPE_PORTS                            = 0                               ;

  // TCDM and log interconnect parameters
  parameter int DATA_WIDTH                               = 32                              ;
  parameter int ADDR_WIDTH                               = 32                              ;
  parameter int BE_WIDTH                                 = DATA_WIDTH/8                    ;
  parameter int NB_TCDM_BANKS                            = (NB_CORES == 16) ? 32 : 16      ; // must be 2**N
  parameter int TCDM_SIZE                                = TCDM_SIZE_KB*1024               ;
  parameter int TCDM_BANK_SIZE                           = TCDM_SIZE/NB_TCDM_BANKS         ; // [B]
  parameter int ADDR_MEM_WIDTH                           = $clog2(TCDM_BANK_SIZE/4)        ; // WORD address width per TCDM bank (the word width is 32 bits)
  parameter int TCDM_NUM_ROWS                            = TCDM_BANK_SIZE/4                ; // [words]
  parameter int TCDM_ID_WIDTH                            = NB_CORES+NB_DMAS+4+NB_HWPE_PORTS;
  parameter int TEST_SET_BIT                             = 20                              ; // bit used to indicate a test-and-set operation during a load in TCDM

  // peripheral and periph interconnect parameters
  parameter int PE_ROUTING_LSB                           = 10                              ; // LSB used as routing BIT in periph interco
  parameter int LOG_CLUSTER                              = 5                               ; // unused

  // DMA parameters
  parameter int TCDM_ADD_WIDTH                           = ADDR_MEM_WIDTH + $clog2(NB_TCDM_BANKS) + 2; // BYTE address width TCDM
  parameter int NB_OUTSND_BURSTS                         = 8                               ;
  parameter int MCHAN_BURST_LENGTH                       = 256                             ;

  // I$ parameters
  parameter int ICACHE_SIZE                              = ICACHE_SIZE_KB                  ;
  parameter int FETCH_ADDR_WIDTH                         = 32                              ;
  parameter int SH_FETCH_DATA_WIDTH                      = 128                             ;
  parameter int SH_NB_BANKS                              = (NB_CORES == 4) ? 2 : NB_CORES/4;
  parameter int AXI_ID_IC_WIDTH                          = (USE_DEDICATED_INSTR_IF)?((NB_CORES == 16) ? 3 : 2) : AXI_ID_IN_WIDTH ;
  parameter int SH_NB_WAYS                               = 4                               ;
  parameter int SH_CACHE_SIZE                            = ICACHE_SIZE*1024                ;
  parameter int SH_CACHE_LINE                            = 1                               ;
  parameter int PRI_NB_WAYS                              = 2;//4                               ;
  parameter int PRI_CACHE_SIZE                           = 512                             ;
  parameter int PRI_CACHE_LINE                           = 1                               ;

  // Formula to calculate PRI_TAG_ADDR_WIDTH, PRI_TAG_WIDTHPRI_DATA_ADDR_WIDTH, PRI_DATA_WIDTH
  parameter int L2_SIZE                                  = L2_SIZE_KB*1024                                ;
  parameter int PRI_REDUCE_TAG_WIDTH                     = $clog2(L2_SIZE/PRI_CACHE_SIZE)+$clog2(PRI_NB_WAYS)+1      ; // add one bit for TAG valid info field
  parameter int OFFSET                                   = $clog2(SH_FETCH_DATA_WIDTH)-3                  ;
  parameter int WAY_SIZE                                 = PRI_CACHE_SIZE/PRI_NB_WAYS                     ;
  parameter int PRI_NB_ROWS                              = WAY_SIZE/(PRI_CACHE_LINE*SH_FETCH_DATA_WIDTH/8); // TAG
  parameter int PRI_TAG_ADDR_WIDTH                       = $clog2(PRI_NB_ROWS)                            ;
  parameter int PRI_TAG_WIDTH                            = (USE_REDUCED_TAG == 1) ? PRI_REDUCE_TAG_WIDTH : (FETCH_ADDR_WIDTH - PRI_TAG_ADDR_WIDTH - $clog2(PRI_CACHE_LINE) - OFFSET + 1);
  parameter int PRI_DATA_WIDTH                           = SH_FETCH_DATA_WIDTH                            ;
  parameter int PRI_DATA_ADDR_WIDTH                      = $clog2(PRI_NB_ROWS)+$clog2(PRI_CACHE_LINE)     ; // Because of 32 Access

  // Formula to calculate SH_TAG_ADDR_WIDTH, SH_TAG_DATA_WIDTH, SH_DATA_ADDR_WIDTH, SH_DATA_DATA_WIDTH
  parameter int SH_REDUCE_TAG_WIDTH                      = $clog2(L2_SIZE/ (SH_CACHE_SIZE/SH_NB_BANKS) )+$clog2(SH_NB_WAYS)-$clog2(SH_NB_BANKS); // TBC : SH_CACHE_SIZE/SH_NB_BANKS
  parameter int OFFSET_BIT                               = $clog2(SH_FETCH_DATA_WIDTH/8)                                ;
  parameter int SH_DATA_DATA_WIDTH                       = SH_FETCH_DATA_WIDTH*SH_CACHE_LINE                            ;
  parameter int SH_DATA_BE_WIDTH                         = SH_DATA_DATA_WIDTH/8                                         ;
  parameter int SH_DATA_NB_ROWS                          = ((SH_CACHE_SIZE/SH_NB_BANKS)*8)/(SH_NB_WAYS*SH_DATA_DATA_WIDTH);
  parameter int SH_DATA_ADDR_WIDTH                       = $clog2(SH_DATA_NB_ROWS)                                      ;
  parameter int SH_TAG_ADDR_NB_ROWS                      = ((SH_CACHE_SIZE/SH_NB_BANKS)*8)/(SH_NB_WAYS*SH_DATA_DATA_WIDTH);
  parameter int SH_TAG_ADDR_WIDTH                        = $clog2(SH_TAG_ADDR_NB_ROWS)                                  ;
  parameter int SH_TAG_DATA_WIDTH                        = (USE_REDUCED_TAG == 1) ? (SH_REDUCE_TAG_WIDTH + 1) : (FETCH_ADDR_WIDTH - OFFSET_BIT - $clog2(SH_NB_BANKS) - $clog2(SH_CACHE_LINE) - SH_TAG_ADDR_WIDTH + 1);

  parameter bit PRIVATE_ICACHE                           = 1;
  parameter bit HIERARCHY_ICACHE_32BIT                   = 1;


  //Ensure that the input AXI ID width is big enough to accomodate the accomodate the IDs of internal wiring - TODO
  //if (AXI_ID_IN_WIDTH < 1 + $clog2(SH_NB_BANKS))
  //         $error("AXI input ID width must be larger than 1+$clog2(SH_NB_BANKS) which is %d but was %d", 1 + $clog2(SH_NB_BANKS), AXI_ID_IN_WIDTH);


  // Miscellaneous
  parameter int LOG_DEPTH                                = 3                        ;
  parameter int ASYNC_EVENT_DATA_WIDTH                   = (2**LOG_DEPTH)*EVNT_WIDTH;
  parameter int DEBUG_FETCH_INTERFACE                    = 0                        ;


endpackage

`endif
