// Copyright 2014-2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

////////////////////////////////////////////////////////////////////////////////
// Company:        Multitherman Laboratory @ DEIS - University of Bologna     //
//                    Viale Risorgimento 2 40136                              //
//                    Bologna - fax 0512093785 -                              //
//                                                                            //
// Engineer:       Davide Rossi - davide.rossi@unibo.it                       //
//                                                                            //
// Additional contributions by:                                               //
//                 Andreas Traber - atraber@iis.ee.ethz.ch                    //
//                 Stefan Mach - smach@iis.ee.ethz.ch                         //
//                                                                            //
// Create Date:    13/02/2013                                                 //
// Design Name:    ULPSoC                                                     //
// Module Name:    ulpcluster_top                                             //
// Project Name:   ULPSoC                                                     //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    ULPSoC cluster                                             //
//                                                                            //
// Revision:                                                                  //
// Revision v0.1 - File Created                                               //
// Revision v0.2 - Added DVS-DVSE support for memories                        //
// Revision v0.3 - Cleand Code, added non-blocking assign in the always_ff    //
// Revision v0.4 - Updated the address range from [4:3] to[3:2]               //
// Revision v0.5 - Restored Back Addr range [4:3], because of TB issues       //
// Revision v0.6 - 29/05/15 : removed DVS-DVSE, added HS,LS,RM,WM             //
//                 LS is default 1, other are '0 by default                   //
// Revision v?   - Added fregfile_disable to the cluster control register     //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// Memory Map
//
// 0x000:        EoC. Write to bit 0 sets the eoc signal
// 0x008:        Fetch Enable. Each core has its own bit, starts from LSB
// 0x010:        Event. Bit 0 triggers an event. Usually not connected
// 0x014:        Cluster Config.
// 0x018:        HWPE Config. RM, WM, HS, LS, HWPE_SEL
// 0x020:        Cluster Clock Gate. Bit 0 enables it
// 0x028:        Debug Status/Resume. Each core has its own bit, starts from LSB
//               On read: Bit is set when core is halted
//               On write: Resume core x when bit x is set
// 0x038:        Debug Halt Mask. Each core has its own bit, starts from LSB
//               When bit is set, core will be part of mask group and stopped
//               when one of the members of the group stops
// 0x040-0x07F:  Boot Addresses. Each core has its own 32-bit boot address
// 0x80:         TCDM arbitration configuration CH0 (CORE)
// 0x88:         TCDM arbitration configuration CH1 (DMA HWCE)
////////////////////////////////////////////////////////////////////////////////


module cluster_control_unit
import hci_package::*;
#(
    parameter NB_CORES        = 4,
    parameter HWPE_PRESENT    = 1,
    parameter FPU             = 0,
    parameter TCDM_SIZE       = 32*1024,
    parameter ICACHE_SIZE     = 4,
    parameter USE_REDUCED_TAG = 0,
    parameter L2_SIZE         = 256*1024,
    parameter PER_ID_WIDTH    = 5,
    parameter ROM_BOOT_ADDR   = 32'h1A000000,
    parameter BOOT_ADDR       = 32'h1C000000
)
(
    input logic                       clk_i,
    input logic                       rst_ni,
    input logic                       en_sa_boot_i,
    input logic                       fetch_en_i,
    XBAR_PERIPH_BUS.Slave             speriph_slave,

    output logic                      event_o,
    output logic                      eoc_o,

    output logic                      cluster_cg_en_o,

    output logic                      hwpe_en_o,
    output hci_interconnect_ctrl_t    hci_ctrl_o,

    output logic                      fregfile_disable_o,

    input  logic [NB_CORES-1:0]       core_halted_i,  // cores are in halted mode (which means debugging)
    output logic [NB_CORES-1:0]       core_halt_o,    // halt the core
    output logic [NB_CORES-1:0]       core_resume_o,  // resume the core

    output logic [NB_CORES-1:0]       fetch_enable_o,
    output logic [NB_CORES-1:0][31:0] boot_addr_o,
    output logic [1:0]                TCDM_arb_policy_o
);

  localparam OFFSET_1      = 4; // It was RM
  localparam OFFSET_2      = 4; // It was WM

  localparam CTRL_UNIT_ADDR = 14'h0000;

  logic                               rvalid_q, rvalid_n;
  logic [PER_ID_WIDTH-1:0]            id_q, id_n;
  logic [31:0]                        rdata_q, rdata_n;
  logic                               ropc_q, ropc_read_n, ropc_write_n;
  logic [NB_CORES-1:0]                fetch_en_q, fetch_en_n;

  logic [NB_CORES-1:0]                dbg_halt_mask_q, dbg_halt_mask_n;
  logic                               core_halted_any_q, core_halted_any_n;

  logic                               eoc_n;
  logic                               event_n;

  logic                               hwpe_en_n;
  logic [10:0]                        hci_ctrl_n, hci_ctrl_q;

  logic                               fregfile_disable_n;

  logic [NB_CORES-1:0][31:0]          boot_addr_n;

  logic [1:0]                         fetch_en_sync;
  logic                               start_fetch;
  logic                               start_boot;
  logic                               cluster_cg_en_n;

  logic [1:0]                         TCDM_arb_policy_n;

  logic                               core_halt_rising_edge;

  logic [31:0]                        s_read_data;

  enum logic [1:0] { RESET, BOOT, WAIT_FETCH, LIMBO } boot_cs, boot_ns;

  assign fetch_enable_o  = fetch_en_q;

  assign hci_ctrl_o.arb_policy         = hci_ctrl_q[10:9];
  assign hci_ctrl_o.hwpe_prio          = hci_ctrl_q[8];
  assign hci_ctrl_o.low_prio_max_stall = hci_ctrl_q[7:0];

  always_comb
  begin
    boot_ns     = boot_cs;
    start_boot  = 1'b0;
    start_fetch = 1'b0;

    case (boot_cs)
      RESET: begin
        boot_ns = BOOT;
      end

      BOOT: begin
        boot_ns = WAIT_FETCH;
        if (en_sa_boot_i)
          start_boot = 1'b1;
      end

      WAIT_FETCH: begin
        if (fetch_en_sync[1]) begin
          start_fetch = 1'b1;
          boot_ns     = LIMBO;
        end
      end

      LIMBO: begin
        boot_ns = LIMBO;
      end
    endcase
  end

  ////////ASYNCH SIGNAL SYNCHRONIZER + EDGE DETECTOR\\\\\\\\
  always_ff @(posedge clk_i, negedge rst_ni)
  begin
    if(rst_ni == 1'b0)
    begin
      fetch_en_sync <= 2'b0;
      boot_cs       <= RESET;
    end
    else
    begin
      fetch_en_sync <= {fetch_en_sync[0],fetch_en_i};
      boot_cs       <= boot_ns;
    end
  end

  // read logic
  always_comb
  begin
    s_read_data  = '0;

    ropc_read_n = 1'b0;

    if (speriph_slave.req && speriph_slave.we_n)
    begin
      ropc_read_n = 1'b0;
      if(speriph_slave.add[20:8] == CTRL_UNIT_ADDR) begin //TODO : verify this
          case (speriph_slave.add[7:6])
          2'b00: begin
            case (speriph_slave.add[5:2])
              4'b0000:
              begin
                s_read_data[0] = eoc_o;
              end

              4'b0010:
              begin
                s_read_data[NB_CORES-1:0] = fetch_en_q;
              end

              4'b0101: //Cluster config
              begin
                  s_read_data = '0;
                  s_read_data[31:10] = L2_SIZE >> 10;
                  s_read_data[8] = (USE_REDUCED_TAG == 1) ? 1'b1 : 1'b0;
                  case(ICACHE_SIZE)
                    4       : s_read_data[7:6] = 2'b00;
                    8       : s_read_data[7:6] = 2'b01;
                    16      : s_read_data[7:6] = 2'b10;
                    default : s_read_data[7:6] = 2'b11;
                  endcase
                  case (TCDM_SIZE)
                    32*1024  : s_read_data[5:4] = 2'b00;
                    64*1024  : s_read_data[5:4] = 2'b01;
                    128*1024 : s_read_data[5:4] = 2'b10;
                    default  : s_read_data[5:4] = 2'b11;
                  endcase
                  s_read_data[2] = (FPU == 1) ? 1'b1 : 1'b0;
                  case (NB_CORES)
                    4       : s_read_data[1:0] = 2'b01;
                    8       : s_read_data[1:0] = 2'b10;
                    16      : s_read_data[1:0] = 2'b11;
                    default : s_read_data[1:0] = 2'b00;
                  endcase
              end

              4'b0110:
              //      +------------------------------------------------+
              // ADDR |   unused   | fregfile_dis | hwpe_en | hci_ctrl |
              // 0x18 |   31..13   |      12      |   11    |  10..0   |
              //      +------------------------------------------------+
              begin
                if(HWPE_PRESENT == 1) begin
                  s_read_data[OFFSET_2+OFFSET_1+1]          = 0;
                  s_read_data[OFFSET_2+OFFSET_1  ]          = 0;
                  s_read_data[OFFSET_2+OFFSET_1-1:OFFSET_1] = 0;
                  s_read_data[OFFSET_1-1:0]                 = 0;
                  s_read_data[OFFSET_2+OFFSET_1+2:0]        = hci_ctrl_q;
                  s_read_data[OFFSET_2+OFFSET_1+3]          = hwpe_en_o;
                  s_read_data[OFFSET_2+OFFSET_1+4]          = fregfile_disable_o;
                end else begin
                  ropc_read_n = 1'b1;
                  s_read_data     = 32'hDEAD_BEEF;
                end
              end

              4'b1000: s_read_data[0] = cluster_cg_en_o;
              4'b1010: s_read_data[NB_CORES-1:0] = core_halted_i[NB_CORES-1:0];
              4'b1110: s_read_data[NB_CORES-1:0] = dbg_halt_mask_q[NB_CORES-1:0];

              default:
              begin
                ropc_read_n = 1'b1;
                s_read_data     = 32'hDEAD_BEEF;
              end
            endcase
          end

          2'b01: // (Code below modified to fix INDEX_ILLEGAL reported by LINT tools)
          begin
            if (NB_CORES == 4) begin
              if (speriph_slave.add[5:4] == 2'h0) begin
                s_read_data = boot_addr_n[speriph_slave.add[3:2]];
              end
            end else if (NB_CORES == 8) begin
              if (speriph_slave.add[5] == 1'h0) begin
                s_read_data = boot_addr_n[speriph_slave.add[4:2]];
              end
            end else begin
              s_read_data = boot_addr_n[speriph_slave.add[5:2]];
            end
          end
          2'b10: //7:6
          begin
              case(speriph_slave.add[5:2])
              4'b0000:
              begin
                s_read_data[0] = TCDM_arb_policy_o[0];
              end
              4'b0010:
              begin
                s_read_data[0] = TCDM_arb_policy_o[1];
              end
              default:
              begin
                ropc_read_n  = 1'b1;
                s_read_data = 32'hDEAD_BEEF;
              end
              endcase // speriph_slave.add[3]
          end
          default:
          begin
            ropc_read_n  = 1'b1;
            s_read_data = 32'hDEAD_BEEF;
          end
        endcase // speriph_slave.add[7:6]
      end else begin //error
        ropc_read_n  = 1'b1;
        s_read_data = 32'hDEAD_BEEF;
      end
    end
  end

  // write logic
  always_comb
  begin
    hwpe_en_n   = hwpe_en_o;
    hci_ctrl_n  = hci_ctrl_q;

    fregfile_disable_n = fregfile_disable_o;

    fetch_en_n  = fetch_en_q;
    eoc_n       = eoc_o;
    event_n     = event_o;

    boot_addr_n     = boot_addr_o;
    cluster_cg_en_n = cluster_cg_en_o;

    TCDM_arb_policy_n = TCDM_arb_policy_o;

    core_resume_o   = '0;
    dbg_halt_mask_n = dbg_halt_mask_q;
    ropc_write_n    = 1'b0;

    if (speriph_slave.req && (~speriph_slave.we_n))
    begin
      ropc_write_n = 1'b0;
      if(speriph_slave.add[20:8] == CTRL_UNIT_ADDR) begin //TODO : verify this
        case (speriph_slave.add[7:6])
        2'b00:
        begin
          case (speriph_slave.add[5:2])
            4'b0000: begin
              eoc_n = speriph_slave.wdata[0];
            end

            4'b0010: begin
              fetch_en_n[NB_CORES-1:0] = speriph_slave.wdata[NB_CORES-1:0];
            end

            4'b0100: begin
              event_n = speriph_slave.wdata[0];
            end

            4'b0110: begin
              if(HWPE_PRESENT == 1) begin
                hci_ctrl_n = speriph_slave.wdata[OFFSET_2+OFFSET_1+2:0];
                hwpe_en_n = speriph_slave.wdata[OFFSET_2+OFFSET_1+3];
                fregfile_disable_n = speriph_slave.wdata[OFFSET_2+OFFSET_1+4];
              end else begin
                ropc_write_n = 1'b1;
                hci_ctrl_n = '0;
                hwpe_en_n = 1'b0;
                fregfile_disable_n = 1'b0;
              end
            end
            4'b1000: begin
              cluster_cg_en_n = speriph_slave.wdata[0];
            end
            4'b1010: begin // Debug Status/Resume
              core_resume_o   = speriph_slave.wdata[NB_CORES-1:0];
            end
            4'b1110: begin // Debug Halt Mask
              dbg_halt_mask_n = speriph_slave.wdata[NB_CORES-1:0];
            end
            default: begin
              ropc_write_n = 1'b1;
            end
          endcase
        end
        2'b01: // (Code below modified to fix INDEX_ILLEGAL reported by LINT tools)
        begin
          if (NB_CORES == 4) begin
            if (speriph_slave.add[5:4] == 2'h0) begin
              boot_addr_n[speriph_slave.add[3:2]] = speriph_slave.wdata;
            end
          end else if (NB_CORES == 8) begin
            if (speriph_slave.add[5] == 1'h0) begin
              boot_addr_n[speriph_slave.add[4:2]] = speriph_slave.wdata;
            end
          end else begin
            boot_addr_n[speriph_slave.add[5:2]] = speriph_slave.wdata;
          end
        end
        2'b10:
        begin
          case (speriph_slave.add[5:2])
          4'b0000:  TCDM_arb_policy_n[0] = speriph_slave.wdata[0];
          4'b0010:  TCDM_arb_policy_n[1] = speriph_slave.wdata[0];
          default: begin
            ropc_write_n = 1'b1;
          end
          endcase
        end
        default:
        begin
          ropc_write_n = 1'b1;
        end
      endcase // speriph_slave.add[7:6]
    end else begin //error
      ropc_write_n = 1'b1;
    end
    end
  end

  assign rdata_n = (ropc_write_n == 1'b1) ? 32'hDEAD_BEEF : s_read_data;


  always_ff @(posedge clk_i, negedge rst_ni)
  begin
    if(rst_ni == 1'b0)
    begin
      rdata_q           <= '0;
      id_q              <= '0;
      ropc_q            <= '0;
      rvalid_q          <= 1'b0;

      hwpe_en_o         <= 1'b0;
      hci_ctrl_q        <= '0;

      fregfile_disable_o<= 1'b0;

      fetch_en_q        <= '0;
      eoc_o             <= 1'b0;
      event_o           <= 1'b0;

      dbg_halt_mask_q   <= '0;
      core_halted_any_q <= 1'b0;

      cluster_cg_en_o   <= 1'b0;
      TCDM_arb_policy_o <= 2'b00;

      boot_addr_o       <= '{default: BOOT_ADDR};
    end
    else
    begin
      rvalid_q <= rvalid_n;

      if (rvalid_n)
      begin
        rdata_q <= rdata_n;
        id_q    <= id_n;
        if(speriph_slave.we_n) begin
          ropc_q  <= ropc_read_n;
        end else begin
          ropc_q <= ropc_write_n;
        end
      end

      hwpe_en_o         <= hwpe_en_n;
      hci_ctrl_q        <= hci_ctrl_n;

      fregfile_disable_o<= fregfile_disable_n;

      cluster_cg_en_o   <= cluster_cg_en_n;

      eoc_o             <= eoc_n;
      event_o           <= event_n;

      dbg_halt_mask_q   <= dbg_halt_mask_n;
      core_halted_any_q <= core_halted_any_n;

      boot_addr_o       <= boot_addr_n;

      TCDM_arb_policy_o <= TCDM_arb_policy_n;

      if (start_fetch)
        fetch_en_q <= '1;
      else
        fetch_en_q <= fetch_en_n;

      if (start_boot) begin
        boot_addr_o[0] <= ROM_BOOT_ADDR;
        fetch_en_q[0]  <= 1'b1;
      end
    end
  end

  // debug halt mode handling
  assign core_halted_any_n = (|(core_halted_i & dbg_halt_mask_q)) & (~core_resume_o);
  assign core_halt_rising_edge = (~core_halted_any_q) & core_halted_any_n;

  assign core_halt_o = {NB_CORES{core_halt_rising_edge}} & dbg_halt_mask_q;

  // to check with igor
  assign speriph_slave.gnt     = 1'b1;
  assign speriph_slave.r_valid = rvalid_q;
  assign speriph_slave.r_opc   = ropc_q;
  assign speriph_slave.r_id    = id_q;
  assign speriph_slave.r_rdata = rdata_q;

  assign rvalid_n = speriph_slave.req;
  assign id_n     = speriph_slave.id;

endmodule
