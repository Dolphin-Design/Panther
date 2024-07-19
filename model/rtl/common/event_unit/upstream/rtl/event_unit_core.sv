// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

import event_unit_pkg::*;

module event_unit_core
#(
  parameter int NB_CORES = 4,
  parameter int NB_SW_EVT = 8,
  parameter int NB_BARR = NB_CORES/2,
  parameter int NB_HW_MUT = 2,
  parameter int MUTEX_MSG_W = 32,
  parameter int PER_ID_WIDTH  = 5
)
(
  // clock and reset
  input  logic clk_i,
  input  logic rst_ni,

  // master event lines, partially private for a specific core
  input  logic [31:0] master_event_lines_i,

  // sw event generation output
  output logic [NB_SW_EVT-1:0] core_sw_events_o,
  output logic [NB_CORES-1:0]  core_sw_events_mask_o,

  // barrier trigger output
  output logic [NB_BARR-1:0]   hw_barr_id_o,

  // request and message for mutex units
  output logic [NB_HW_MUT-1:0]                  mutex_rd_req_o,
  output logic [NB_HW_MUT-1:0]                  mutex_wr_req_o,
  output logic [NB_HW_MUT-1:0][MUTEX_MSG_W-1:0] mutex_msg_wdata_o,
  input  logic [NB_HW_MUT-1:0][MUTEX_MSG_W-1:0] mutex_msg_rdata_i,

  // signals for entry point dispatch
  output logic        dispatch_pop_req_o,
  output logic        dispatch_pop_ack_o,
  input  logic [31:0] dispatch_value_i,

  output logic        dispatch_w_req_o,
  output logic [31:0] dispatch_w_data_o,
  output logic [1:0]  dispatch_reg_sel_o,

  // clock and interrupt request to core
  output logic        core_irq_req_o,
  output logic [4:0]  core_irq_id_o,
  input  logic        core_irq_ack_i,
  input  logic [4:0]  core_irq_ack_id_i,

  input  logic        core_busy_i,
  output logic        core_clock_en_o,

  input  logic        dbg_req_i,
  output logic        core_dbg_req_o,

  // periph bus slave for regular register access
  XBAR_PERIPH_BUS.Slave periph_int_bus_slave,
  // demuxed periph for fast register access and event trigger
  XBAR_PERIPH_BUS.Slave eu_direct_link_slave

);

  localparam LOG_NB_CORES  = $clog2(NB_CORES);
  localparam LOG_NB_BARR   = $clog2(NB_BARR);
  localparam LOG_NB_HW_MUT = (NB_HW_MUT == 1) ? 1 : $clog2(NB_HW_MUT); // Exception to handle NCIM compilation issue (reversed part-select index expression ordering) when NB_HW_MUT = 1

  // registers
  logic [31:0] event_mask_DP;
  logic [31:0] irq_mask_DP;
  logic [31:0] event_buffer_DP;
  logic [31:0] event_buffer_DN;

  logic        irq_req_del_SP;
  logic        irq_req_del_SN;
  logic        dbg_req_del_SP;
  logic        dbg_req_del_SN;

  logic [NB_CORES-1:0] sw_events_mask_DP;
  logic                wait_clear_access_SP;
  logic                wait_clear_access_SN;
  logic                wakeup_event;
  logic                wakeup_mask_irq_SP;

  logic                trigger_release_SP;
  logic                trigger_release_SN;

  // calculated write data
  logic [31:0] wdata_event_mask_demux;
  logic [31:0] wdata_event_mask_interc;
  logic [31:0] wdata_irq_mask_demux;
  logic [31:0] wdata_irq_mask_interc;
  logic [31:0] wdata_event_buffer_demux;
  logic [31:0] wdata_event_buffer_interc;

  logic [NB_CORES-1:0] wdata_sw_events_mask_demux;
  logic [NB_CORES-1:0] wdata_sw_events_mask_interc;

  // write control
  logic [3:0]  we_demux;
  logic [3:0]  we_interc;

  // combinational signals
  logic [31:0] event_buffer_masked;
  logic [31:0] irq_buffer_masked;
  logic        write_conflict;
  logic        demux_add_is_sleep;
  logic        demux_add_is_clear;
  logic        stop_core_clock;
  logic        core_clock_en;

  logic [31:0] irq_clear_mask;
  logic [4:0]  irq_sel_id;
  logic        irq_pending;

  // multiple sources for sw events (write to trigger and read from wait regs)
  logic [NB_SW_EVT-1:0] sw_events_reg;
  logic [NB_SW_EVT-1:0] sw_events_wait;
  logic [NB_CORES-1:0]  sw_events_mask_reg;
  logic [NB_CORES-1:0]  sw_events_mask_wait;

  // (delayed) bus signals
  logic        p_interc_vld_SP;
  logic        p_interc_vld_SN;
  logic        p_interc_gnt;
  logic        p_interc_req_del_SP;
  logic        p_interc_req_del_SN;
  logic        p_interc_we_n_del_SP;
  logic        p_interc_we_n_del_SN;
  logic [3:0]  p_interc_add_del_SP;
  logic [3:0]  p_interc_add_del_SN;

  logic        p_demux_vld_SP;
  logic        p_demux_vld_SN;
  logic        p_demux_gnt;
  logic        p_demux_gnt_sleep_fsm;
  logic        p_demux_req_del_SP;
  logic        p_demux_req_del_SN;
  logic        p_demux_we_n_del_SP;
  logic        p_demux_we_n_del_SN;
  logic [7:0]  p_demux_add_del_SP;
  logic [7:0]  p_demux_add_del_SN;

  // core clock FSM
  enum logic [1:0] { ACTIVE=0, SLEEP=1, IRQ_WHILE_SLEEP=2 } core_clock_CS, core_clock_NS;

  // ORing of sw event sources
  assign core_sw_events_o      = sw_events_reg | sw_events_wait;
  assign core_sw_events_mask_o = sw_events_mask_reg | sw_events_mask_wait;

  // masking and reduction of buffer
  assign event_buffer_masked   = event_buffer_DP & event_mask_DP;
  assign irq_buffer_masked     = event_buffer_DP & irq_mask_DP;

  // calculation of one-hot clear mask for interrupts
  assign irq_pending           = |irq_buffer_masked;
  assign irq_clear_mask        = (core_irq_ack_i) ? ~(1'b1 << core_irq_ack_id_i) : '1;

  // req/ack handling scheme for interrupts
  assign irq_req_del_SN        = irq_pending;
  assign core_irq_req_o        = irq_req_del_SP;
  assign core_irq_id_o         = irq_sel_id;

  // delaying of debug request to align to interrupt FSM handling
  assign dbg_req_del_SN        = dbg_req_i;
  assign core_dbg_req_o        = dbg_req_del_SP;

  // handshake for dispatch value consumption
  assign dispatch_pop_ack_o    = wakeup_event;

  // handle sleeping requests and conflicting write accesses
  assign demux_add_is_sleep    = ( ({eu_direct_link_slave.add[9:8],eu_direct_link_slave.add[5:3]} == 5'b00_111)      || // core regs _wait and _wait_clear
                                   ( eu_direct_link_slave.add[9:6] == 4'b0_101)                                      || // sw events _wait
                                   ( eu_direct_link_slave.add[9:6] == 4'b0_110)                                      || // sw events _wait_clear
                                   ({eu_direct_link_slave.add[9],eu_direct_link_slave.add[4:2]} == 4'b1_110)         || // barriers _wait
                                   ({eu_direct_link_slave.add[9],eu_direct_link_slave.add[4:2]} == 4'b1_111)         || // barriers _wait_clear
                                   ( eu_direct_link_slave.add[9:6] == 4'b0_011)                                      || // hw mutexes
                                   ({eu_direct_link_slave.add[9:6],eu_direct_link_slave.add[3:2]} == 6'b0010_00 ) );    // hw dispatch fifo_read

  assign demux_add_is_clear    = ( ( eu_direct_link_slave.add[9:2] == 8'b00_0011_11)                                 || // core regs _wait_clear
                                   ( eu_direct_link_slave.add[9:6] == 4'b01_10)                                      || // sw events _wait_clear
                                   ({eu_direct_link_slave.add[9],eu_direct_link_slave.add[4:2]} == 4'b1_111)         || // barriers _wait_clear
                                   ( eu_direct_link_slave.add[9:6] == 4'b00_11)                                      || // hw mutex units - always _wait_clear
                                   ({eu_direct_link_slave.add[9:6],eu_direct_link_slave.add[3:2]} == 6'b0010_00 ) );    // hw dispatch fifo_read
   
  assign stop_core_clock       = ( (eu_direct_link_slave.req == 1'b1) && (eu_direct_link_slave.we_n == 1'b1) && (demux_add_is_sleep == 1'b1) );
  
  assign write_conflict        = ( ({periph_int_bus_slave.req, eu_direct_link_slave.req} == 2'b11) &&
                                   ({periph_int_bus_slave.we_n, eu_direct_link_slave.we_n} == 2'b00)    );

  // link from peripheral demux
  assign p_demux_gnt      = eu_direct_link_slave.req & p_demux_gnt_sleep_fsm & ~wait_clear_access_SP;
  assign p_demux_vld_SN   = p_demux_gnt;

  assign eu_direct_link_slave.gnt     = p_demux_gnt;
  assign eu_direct_link_slave.r_id    = '0;
  assign eu_direct_link_slave.r_opc   = 1'b0;
  assign eu_direct_link_slave.r_valid = p_demux_vld_SP;

  assign p_demux_req_del_SN  = eu_direct_link_slave.req;
  assign p_demux_we_n_del_SN  = eu_direct_link_slave.we_n;
  assign p_demux_add_del_SN  = eu_direct_link_slave.add[9:2];


  // link from peripheral interconnect
  assign p_interc_gnt     = ( (periph_int_bus_slave.req == 1'b1) && (write_conflict == 1'b0) );
  assign p_interc_vld_SN  = p_interc_gnt;

  assign periph_int_bus_slave.gnt     = p_interc_gnt;
  assign periph_int_bus_slave.r_opc   = 1'b0;
  assign periph_int_bus_slave.r_valid = p_interc_vld_SP;
  assign periph_int_bus_slave.r_id    = '0;

  assign p_interc_req_del_SN = periph_int_bus_slave.req;
  assign p_interc_we_n_del_SN = periph_int_bus_slave.we_n;
  assign p_interc_add_del_SN = periph_int_bus_slave.add[5:2];


  //write logic for demux and interconnect port
  always_comb begin : p_write_logic_comb
    // keep old buffer state and buffer newly triggered events
    event_buffer_DN   = (event_buffer_DP | master_event_lines_i) & irq_clear_mask;

    // default: don't write any register
    we_demux                    = '0;
    wdata_event_mask_demux      = '0;
    wdata_irq_mask_demux        = '0;
    wdata_event_buffer_demux    = '0;
    wdata_sw_events_mask_demux  = '0;

    we_interc                   = '0;
    wdata_event_mask_interc     = '0;
    wdata_irq_mask_interc       = '0;
    wdata_event_buffer_interc   = '0;
    wdata_sw_events_mask_interc = '0;

    // default: don't trigger any sw event or barrier
    sw_events_reg      = '0;
    sw_events_mask_reg = '0;

    // default: don't unlock (write) a mutex
    mutex_wr_req_o     = '0;
    mutex_msg_wdata_o  = '0;

    // default: don't push a value to or configure the HW dispatch
    dispatch_w_req_o   = 1'b0;
    dispatch_w_data_o  = '0;
    dispatch_reg_sel_o = '0; 

    // periph demux write access
    if ( (eu_direct_link_slave.req == 1'b1) && (eu_direct_link_slave.we_n == 1'b0) ) begin
      case (eu_direct_link_slave.add[9:6]) // decode reg group
        4'b00_00: begin
          // eu core registers
          case (eu_direct_link_slave.add[5:2])
            4'h0: begin we_demux[0] = 1'b1; wdata_event_mask_demux       = eu_direct_link_slave.wdata;                                    end
            4'h1: begin we_demux[0] = 1'b1; wdata_event_mask_demux       = event_mask_DP & ~eu_direct_link_slave.wdata;                   end
            4'h2: begin we_demux[0] = 1'b1; wdata_event_mask_demux       = event_mask_DP | eu_direct_link_slave.wdata;                    end
            4'h3: begin we_demux[1] = 1'b1; wdata_irq_mask_demux         = eu_direct_link_slave.wdata;                                    end
            4'h4: begin we_demux[1] = 1'b1; wdata_irq_mask_demux         = irq_mask_DP & ~eu_direct_link_slave.wdata;                     end
            4'h5: begin we_demux[1] = 1'b1; wdata_irq_mask_demux         = irq_mask_DP | eu_direct_link_slave.wdata;                      end
            4'ha: begin we_demux[2] = 1'b1; wdata_event_buffer_demux     = event_buffer_DP & ~eu_direct_link_slave.wdata;                 end
            4'hb: begin we_demux[3] = 1'b1; wdata_sw_events_mask_demux   = eu_direct_link_slave.wdata[NB_CORES-1:0];                      end
            4'hc: begin we_demux[3] = 1'b1; wdata_sw_events_mask_demux   = sw_events_mask_DP & ~eu_direct_link_slave.wdata[NB_CORES-1:0]; end
            4'hd: begin we_demux[3] = 1'b1; wdata_sw_events_mask_demux   = sw_events_mask_DP | eu_direct_link_slave.wdata[NB_CORES-1:0];  end
          endcase
        end
        4'b00_10: begin
          // hw dispatch
          dispatch_w_req_o   = 1'b1;
          dispatch_w_data_o  = eu_direct_link_slave.wdata;
          dispatch_reg_sel_o = eu_direct_link_slave.add[3:2];
        end
        4'b00_11: begin // (Code below modified to fix INDEX_ILLEGAL reported by LINT tools)
          if (NB_HW_MUT == 1) begin
            if (eu_direct_link_slave.add[5:2] == 'h0) begin
              mutex_wr_req_o    = 1'b1;
              mutex_msg_wdata_o = eu_direct_link_slave.wdata;
            end 
          end else begin 
            if (eu_direct_link_slave.add[5:2] < NB_HW_MUT) begin
              mutex_wr_req_o[eu_direct_link_slave.add[(LOG_NB_HW_MUT+2)-1:2]]    = 1'b1;
              mutex_msg_wdata_o[eu_direct_link_slave.add[(LOG_NB_HW_MUT+2)-1:2]] = eu_direct_link_slave.wdata;
            end
          end
        end
        4'b01_00, 4'b01_01, 4'b01_10, 4'b01_11: begin
          // handle sw event triggering
          if ( eu_direct_link_slave.add[7:6] == 2'b00 )  begin
            sw_events_reg[eu_direct_link_slave.add[4:2]] = 1'b1;
            // use all-0 state to trigger all cores
            if ( eu_direct_link_slave.wdata[NB_CORES-1:0] == '0 ) begin
              sw_events_mask_reg = '1;
            end else begin
              sw_events_mask_reg = eu_direct_link_slave.wdata[NB_CORES-1:0];
            end
          end
        end
      endcase
    end

    // periph interconnect write access
    if ( (periph_int_bus_slave.req == 1'b1) && (periph_int_bus_slave.we_n == 1'b0) ) begin
      case (periph_int_bus_slave.add[5:2])
        4'h0: begin we_interc[0] = 1'b1; wdata_event_mask_interc     = periph_int_bus_slave.wdata;                                    end
        4'h1: begin we_interc[0] = 1'b1; wdata_event_mask_interc     = event_mask_DP & ~periph_int_bus_slave.wdata;                   end
        4'h2: begin we_interc[0] = 1'b1; wdata_event_mask_interc     = event_mask_DP | periph_int_bus_slave.wdata;                    end
        4'h3: begin we_interc[1] = 1'b1; wdata_irq_mask_interc       = periph_int_bus_slave.wdata;                                    end
        4'h4: begin we_interc[1] = 1'b1; wdata_irq_mask_interc       = irq_mask_DP & ~periph_int_bus_slave.wdata;                     end
        4'h5: begin we_interc[1] = 1'b1; wdata_irq_mask_interc       = irq_mask_DP | periph_int_bus_slave.wdata;                      end
        4'ha: begin we_interc[2] = 1'b1; wdata_event_buffer_interc   = event_buffer_DP & ~periph_int_bus_slave.wdata;                 end
        4'hb: begin we_interc[3] = 1'b1; wdata_sw_events_mask_interc = periph_int_bus_slave.wdata[NB_CORES-1:0];                      end
        4'hc: begin we_interc[3] = 1'b1; wdata_sw_events_mask_interc = sw_events_mask_DP & ~periph_int_bus_slave.wdata[NB_CORES-1:0]; end
        4'hd: begin we_interc[3] = 1'b1; wdata_sw_events_mask_interc = sw_events_mask_DP | periph_int_bus_slave.wdata[NB_CORES-1:0];  end
      endcase
    end

    if ( wait_clear_access_SP == 1'b1 ) begin
      event_buffer_DN = ((event_buffer_DP | master_event_lines_i) & ~event_mask_DP) & irq_clear_mask;
    end else if ( we_demux[2] == 1'b1 ) begin
      event_buffer_DN = (wdata_event_buffer_demux | master_event_lines_i) & irq_clear_mask;
    end else if ( we_interc[2] == 1'b1 ) begin
      event_buffer_DN = (wdata_event_buffer_interc | master_event_lines_i) & irq_clear_mask;
    end
  end



  // read muxes for both links
generate
  always_comb begin : p_read_muxes_comb
    eu_direct_link_slave.r_rdata = '0;
    periph_int_bus_slave.r_rdata = '0;

    // default: don't trigger any sw event or barrier or mutex
    sw_events_wait      = '0;
    sw_events_mask_wait = '0;
    hw_barr_id_o        = '0;
    mutex_rd_req_o      = '0;

    // default: dont'r request to pop a value from the dispatch FIFO
    dispatch_pop_req_o  = 1'b0;

    // read accesses for periph demux port; inclues _wait and _wait_clear regs
    if ( (p_demux_req_del_SP == 1'b1) && (p_demux_we_n_del_SP == 1'b1) ) begin
      case (p_demux_add_del_SP[7:4]) // decode reg group
        4'b00_00: begin // eu core registers
          case (p_demux_add_del_SP[3:0])
            4'h0: eu_direct_link_slave.r_rdata = event_mask_DP;
            4'h3: eu_direct_link_slave.r_rdata = irq_mask_DP;
            4'h6: eu_direct_link_slave.r_rdata = {31'b0, core_clock_en};
            4'h7: eu_direct_link_slave.r_rdata = event_buffer_DP;
            4'h8: eu_direct_link_slave.r_rdata = event_buffer_masked;
            4'h9: eu_direct_link_slave.r_rdata = irq_buffer_masked;
            4'hb: eu_direct_link_slave.r_rdata = {{(32-NB_CORES){1'b0}}, sw_events_mask_DP};
            4'he: eu_direct_link_slave.r_rdata = event_buffer_masked;
            4'hf: eu_direct_link_slave.r_rdata = event_buffer_masked;
          endcase
        end

        4'b00_10: begin // hw dispatch pop request
          if ( p_demux_add_del_SP[1:0] == 2'b00 )
            eu_direct_link_slave.r_rdata = dispatch_value_i;
        end

        // mutex read/lock request (Code below modified to fix INDEX_ILLEGAL reported by LINT tools)
        4'b00_11: begin
          if (NB_HW_MUT == 1) begin
            eu_direct_link_slave.r_rdata = mutex_msg_rdata_i;
          end else begin 
            if (p_demux_add_del_SP[3:0] < NB_HW_MUT) begin
              eu_direct_link_slave.r_rdata = mutex_msg_rdata_i[p_demux_add_del_SP[LOG_NB_HW_MUT-1:0]];
            end
          end
        end

        // barrier trigger
        4'b1000, 4'b1001, 4'b1010, 4'b1011, 4'b1100, 4'b1101, 4'b1110, 4'b1111 : begin
          if ( p_demux_add_del_SP[2:0] == 3'b101 ) begin // barrier trigger self
            eu_direct_link_slave.r_rdata = 'h0;
          end else if ( p_demux_add_del_SP[2:1] == 2'b11 ) begin // barrier trigger wait / wait clear
            eu_direct_link_slave.r_rdata = event_buffer_masked;
          end
        end

        // some wait register for either sw_event
        4'b0101,4'b0110: eu_direct_link_slave.r_rdata = event_buffer_masked;
      endcase
    end

    if ( eu_direct_link_slave.req & eu_direct_link_slave.we_n & trigger_release_SP ) begin
      // trigger sw_event+read buffer+sleep(+clear) accesses
      if ( (eu_direct_link_slave.add[9:6] == 4'b0101) || (eu_direct_link_slave.add[9:6] == 4'b0110) ) begin
        sw_events_wait[eu_direct_link_slave.add[4:2]] = 1'b1;
        // use all-0 state to trigger all cores
        if ( sw_events_mask_DP == '0 ) begin
          sw_events_mask_wait = '1;
        end else begin
          sw_events_mask_wait = sw_events_mask_DP;
        end
      end

      // trigger hw_barrier+read buffer(+sleep)(+clear) accesses (Code below modified to fix INDEX_ILLEGAL reported by LINT tools)
      if ( ({eu_direct_link_slave.add[9],eu_direct_link_slave.add[4:2]} == 4'b1_101) ||
           ({eu_direct_link_slave.add[9],eu_direct_link_slave.add[4:2]} == 4'b1_110) ||
           ({eu_direct_link_slave.add[9],eu_direct_link_slave.add[4:2]} == 4'b1_111)    )
      begin
        if (NB_BARR == 1) begin
          if (eu_direct_link_slave.add[8:5] == 'h0) begin
            hw_barr_id_o = 1'b1;
          end
        end else begin
          if (eu_direct_link_slave.add[8:5] < NB_BARR) begin
            hw_barr_id_o[eu_direct_link_slave.add[(LOG_NB_BARR+5)-1:5]] = 1'b1;
          end
        end
      end

      // try to lock a mutex (Code below modified to fix INDEX_ILLEGAL reported by LINT tools)
      if ( eu_direct_link_slave.add[9:6] == 4'b0_011 ) begin
        if (NB_HW_MUT==1) begin
          if (eu_direct_link_slave.add[5:2] == 4'h0) begin
            mutex_rd_req_o = 1'h1;
          end
        end else begin if (eu_direct_link_slave.add[5:2] < NB_HW_MUT) begin
            mutex_rd_req_o[eu_direct_link_slave.add[(LOG_NB_HW_MUT+2)-1:2]] = 1'b1;
          end
        end
      end

      // try to pop a value from the dispatch FIFO
      if ( eu_direct_link_slave.add[9:2] == 8'b0_01000_00 ) begin
        dispatch_pop_req_o = 1'b1;
      end

    end

    // only regular read accesses for interconnect port
    if ( (p_interc_req_del_SP == 1'b1) && (p_interc_we_n_del_SP == 1'b1) ) begin
      case (p_interc_add_del_SP)
        4'h0: periph_int_bus_slave.r_rdata = event_mask_DP;
        4'h3: periph_int_bus_slave.r_rdata = irq_mask_DP;
        4'h6: periph_int_bus_slave.r_rdata = {31'b0, core_clock_en};
        4'h7: periph_int_bus_slave.r_rdata = event_buffer_DP;
        4'h8: periph_int_bus_slave.r_rdata = event_buffer_masked;
        4'h9: periph_int_bus_slave.r_rdata = irq_buffer_masked;
        4'hb: periph_int_bus_slave.r_rdata = {{(32-NB_CORES){1'b0}}, sw_events_mask_DP};
      endcase
    end
  end
endgenerate

  // FSM for controlling the core clock
  always_comb begin : p_core_clock_fsm
    core_clock_NS         = core_clock_CS;
    core_clock_en         = 1'b1;
    p_demux_gnt_sleep_fsm = 1'b1;
    wait_clear_access_SN  = 1'b0;
    wakeup_event          = 1'b0;

    trigger_release_SN    = trigger_release_SP;

    case (core_clock_CS)
      ACTIVE: begin
        // check if there is any sleep request at all
        if ( stop_core_clock ) begin
          // If there is already an irq request sent to the core, the replay is not properly detected.
          if ( irq_pending | dbg_req_i ) begin
            // avoids split/illegal transactions (gnt but no r_valid) 
            p_demux_gnt_sleep_fsm = 1'b0;
            trigger_release_SN    = 1'b0;
            core_clock_NS = IRQ_WHILE_SLEEP;
          end else begin
            // corner-case: event already triggered while going to sleep
            if ( |event_buffer_masked ) begin
              // make sure the next req can trigger units again
              trigger_release_SN = 1'b1;
              // signal state change through incoming event
              wakeup_event = 1'b1;
              // handle buffer clear cases
              if ( demux_add_is_clear ) begin
                wait_clear_access_SN = 1'b1;
              end
            end else begin
              p_demux_gnt_sleep_fsm = 1'b0;
              // block further unit triggering until return to ACTIVE
              trigger_release_SN = 1'b0;
              if ( ~core_busy_i ) begin
                core_clock_NS = SLEEP;
              end
            end
          end
        end
      end
      SLEEP: begin
        core_clock_en         = 1'b0;
        p_demux_gnt_sleep_fsm = 1'b0;

        if ( irq_pending | dbg_req_i ) begin
          core_clock_en = 1'b1;
          core_clock_NS = IRQ_WHILE_SLEEP;
        end else if ( |event_buffer_masked ) begin
          core_clock_en = 1'b1;

          if ( demux_add_is_clear ) begin
            wait_clear_access_SN = 1'b1;
          end;
          p_demux_gnt_sleep_fsm = 1'b1;
          wakeup_event          = 1'b1;

          trigger_release_SN = 1'b1;
          core_clock_NS = ACTIVE;
        end
      end
      IRQ_WHILE_SLEEP: begin
        if ( stop_core_clock ) begin
          if ( ~irq_pending & ~dbg_req_i ) begin   
            if ( |event_buffer_masked ) begin
              core_clock_en = 1'b1;

              if ( demux_add_is_clear ) begin 
                wait_clear_access_SN = 1'b1; 
              end;
              p_demux_gnt_sleep_fsm = 1'b1;
              wakeup_event          = 1'b1;

              trigger_release_SN = 1'b1;
              core_clock_NS = ACTIVE;
            end else begin
              p_demux_gnt_sleep_fsm = 1'b0;
              if ( ~core_busy_i ) begin 
                core_clock_NS = SLEEP;
              end
            end
          end
        end
      end

      default:
        begin
          core_clock_NS = ACTIVE;
        end

    endcase
  end

  assign core_clock_en_o = core_clock_en;

  // find first leading 1 for current irq priorization scheme
  fl1_loop #(
    .WIDTH(32) )
  fl1_loop_i (
    .vector_i(irq_buffer_masked),
    .idx_bin_o(irq_sel_id),
    .no1_o()
  );

  always_ff @(posedge clk_i, negedge rst_ni) begin
    if ( rst_ni == 1'b0 ) begin
      core_clock_CS        <= ACTIVE;
      event_mask_DP        <= '0;
      irq_mask_DP          <= '0;
      irq_req_del_SP       <= '0;
      dbg_req_del_SP       <= '0;
      event_buffer_DP      <= '0;
      wait_clear_access_SP <= 1'b0;
      trigger_release_SP   <= 1'b1;
      sw_events_mask_DP    <= '0;

      p_demux_vld_SP       <= 1'b0;
      p_demux_add_del_SP   <= '0;
      p_demux_req_del_SP   <= 1'b0;
      p_demux_we_n_del_SP   <= 1'b0;
      p_interc_vld_SP      <= 1'b0;
      p_interc_add_del_SP  <= '0;
      p_interc_req_del_SP  <= 1'b0;
      p_interc_we_n_del_SP  <= 1'b0;


      wakeup_mask_irq_SP   <= '0;
    end
    else begin
      core_clock_CS        <= core_clock_NS;

      // write arbiters - demux write access takes priority
      if ( we_demux[0] == 1'b1 ) begin
        event_mask_DP   <= wdata_event_mask_demux;
      end else if ( we_interc[0] == 1'b1 ) begin
        event_mask_DP   <= wdata_event_mask_interc;
      end

      if ( we_demux[1] == 1'b1 ) begin
        irq_mask_DP     <= wdata_irq_mask_demux;
      end else if ( we_interc[1] == 1'b1 ) begin
        irq_mask_DP     <= wdata_irq_mask_interc;
      end

      if ( wait_clear_access_SP | core_irq_ack_i | (|master_event_lines_i) | we_demux[2] | we_interc[2] ) begin
        event_buffer_DP <= event_buffer_DN;
      end

      if ( we_demux[3] == 1'b1 ) begin
        sw_events_mask_DP <= wdata_sw_events_mask_demux;
      end else if ( we_interc[3] == 1'b1 ) begin
        sw_events_mask_DP <= wdata_sw_events_mask_interc;
      end

      irq_req_del_SP       <= irq_req_del_SN;

      dbg_req_del_SP       <= dbg_req_del_SN;

      wait_clear_access_SP <= wait_clear_access_SN;

      wakeup_mask_irq_SP   <= wakeup_event;

      trigger_release_SP   <= trigger_release_SN;

      p_demux_req_del_SP   <= p_demux_req_del_SN;
      p_demux_we_n_del_SP   <= p_demux_we_n_del_SN;
      p_demux_vld_SP       <= p_demux_vld_SN;

      if(eu_direct_link_slave.req & eu_direct_link_slave.gnt) begin
        p_demux_add_del_SP   <= p_demux_add_del_SN;
      end

      p_interc_req_del_SP  <= p_interc_req_del_SN;
      p_interc_we_n_del_SP  <= p_interc_we_n_del_SN;
      p_interc_vld_SP      <= p_interc_vld_SN;

      if(periph_int_bus_slave.req & periph_int_bus_slave.gnt) begin
        p_interc_add_del_SP  <= p_interc_add_del_SN;
      end

    end
  end

endmodule // event_unit_core
