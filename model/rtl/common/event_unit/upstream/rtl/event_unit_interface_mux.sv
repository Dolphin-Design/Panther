// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

module event_unit_interface_mux
#(
  parameter int NB_CORES       = 4,
  parameter int NB_BARR        = NB_CORES/2,
  parameter int PER_ID_WIDTH   = NB_CORES+1,
  parameter int NB_SW_EVT      = 8,
  parameter int NB_HW_MUT      = 1
)
(
  // clock and reset
  input  logic              clk_i,
  input  logic              rst_ni,

  // slave port from periph interconnect, decode requests
  XBAR_PERIPH_BUS.Slave     speriph_slave,
  XBAR_PERIPH_BUS.Master    periph_int_bus_master[NB_CORES+NB_BARR+2:0],

  // demuxed slave ports from each core, redistribute to eu_core and barrier units
  XBAR_PERIPH_BUS.Slave     demux_slave[NB_CORES-1:0],
  XBAR_PERIPH_BUS.Master    demux_int_bus_core_master[NB_CORES-1:0],
  XBAR_PERIPH_BUS.Master    demux_int_bus_barrier_master[NB_BARR-1:0]
);


  genvar I,J;

  localparam LOG_NB_CORES = $clog2(NB_CORES);
  localparam LOG_NB_BARR  = $clog2(NB_BARR);

  //*************************************************************//
  //                                                             //
  //       ██████╗ ███████╗███╗   ███╗██╗   ██╗██╗  ██╗          //
  //       ██╔══██╗██╔════╝████╗ ████║██║   ██║╚██╗██╔╝          //
  //       ██║  ██║█████╗  ██╔████╔██║██║   ██║ ╚███╔╝           //
  //       ██║  ██║██╔══╝  ██║╚██╔╝██║██║   ██║ ██╔██╗           //
  //       ██████╔╝███████╗██║ ╚═╝ ██║╚██████╔╝██╔╝ ██╗          //
  //       ╚═════╝ ╚══════╝╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═╝          //
  //                                                             //
  //*************************************************************//


  // response channel for demux plug
  logic [NB_CORES-1:0]                  demux_ip_sel_SP;
  logic [NB_CORES-1:0][LOG_NB_BARR-1:0] demux_barr_sel_SP;
  logic [NB_CORES-1:0]                  demux_slave_req_del;
  logic [NB_CORES-1:0]                  demux_slave_update;
  logic [NB_CORES-1:0]                  demux_add_is_core;
  logic [NB_CORES-1:0]                  demux_add_is_barr;
  logic [NB_CORES-1:0]                  demux_add_is_core_del;
  logic [NB_CORES-1:0]                  demux_add_is_barr_del;
  logic [NB_CORES-1:0]                  demux_slave_gnt_mux;
  logic [NB_CORES-1:0]                  demux_slave_gnt_mux_del;

  // helper arrays to work around sv dynamic bus index select limitation
  logic [NB_CORES-1:0]                  demux_slaves_core_req;
  
  logic [NB_CORES-1:0]                  demux_slave_we_n;
  logic [NB_CORES-1:0][31:0]            demux_slave_add;
  logic [NB_CORES-1:0][31:0]            demux_slave_wdata;
  logic [NB_CORES-1:0]                  demux_slave_rvalid_barr;

  logic [NB_BARR-1:0][31:0]             demux_int_bus_barrier_master_r_rdata;
  logic [NB_CORES-1:0][NB_BARR-1:0]     demux_slv_bar_req_int;
  logic [NB_BARR-1:0][NB_CORES-1:0]     demux_slv_bar_req_int_transp;

  logic [NB_BARR-1:0][LOG_NB_CORES-1:0] barr_arb_sel;
  logic [NB_BARR-1:0][LOG_NB_CORES-1:0] barr_arb_ff1;
  logic [NB_BARR-1:0]                   barr_arb_no1;

  logic [NB_CORES-1:0][NB_BARR-1:0]     demux_slave_gnt_barr;
  logic [NB_CORES-1:0][LOG_NB_BARR-1:0] demux_slave_gnt_barr_bin;

  logic [NB_CORES-1:0]                  demux_slave_aligned_access_err;
  logic [NB_CORES-1:0]                  demux_slave_aligned_access_err_del;
  logic [NB_CORES-1:0]                  demux_slave_core_buffer_ro_err;
  logic [NB_CORES-1:0]                  demux_slave_core_buffer_ro_err_del;
  logic [NB_CORES-1:0]                  demux_slave_core_hw_barr_ro_err;
  logic [NB_CORES-1:0]                  demux_slave_core_hw_barr_ro_err_del;
  logic [NB_CORES-1:0]                  demux_slave_core_trigg_ro_err;
  logic [NB_CORES-1:0]                  demux_slave_core_trigg_ro_err_del;
  logic [NB_CORES-1:0]                  demux_slave_core_ro_err;
  logic [NB_CORES-1:0]                  demux_slave_core_ro_err_del;
  logic [NB_CORES-1:0]                  demux_slave_hw_barr_ro_err;
  logic [NB_CORES-1:0]                  demux_slave_hw_barr_ro_err_del;
  logic [NB_CORES-1:0]                  demux_slave_reg_err;
  logic [NB_CORES-1:0]                  demux_slave_reg_err_del;

  generate
    for ( I = 0; I < NB_CORES; I++ ) begin : g_demux_slave_master
      // slave->master: output ports to cores
      assign demux_slave[I].gnt   = demux_slave_gnt_mux[I];

      assign demux_slave[I].r_id  = '0;
      // activation condition for responses on each demux plug
      assign demux_slave_update[I] = ( (demux_slave[I].req & ~demux_slave_req_del[I]) ||
                                       (~demux_slave[I].req & demux_slave_req_del[I]) ||
                                       (demux_slave[I].req & demux_slave_gnt_mux[I])  ||
                                       (demux_slave_req_del[I] & demux_slave_gnt_mux_del[I]));
      // check if Core I wants to access its private event_unit_core
      assign demux_add_is_core[I]  = ( ( demux_slave[I].add[9:6] == 4'b0         )                   ||    // some core reg 
                                       ( demux_slave[I].add[9:3] == 7'b00_1000_0 )                   ||    // some core reg : hw_dispatch
                                       ( demux_slave[I].add[9:6] == 4'b00_11     )                   ||    // some core reg : mutex 
                                       ( demux_slave[I].add[9:5] == 5'b01000     )                   ||    // some core reg : trig_sw 
                                       ( demux_slave[I].add[9:5] == 5'b01010     )                   ||    // some core reg : trig_sw wait
                                       ( demux_slave[I].add[9:5] == 5'b01100     )                   ||    // some core reg : trig_sw wait clear
                                       ({demux_slave[I].add[9],demux_slave[I].add[4:2]} == 4'b11_01) ||    // barrier_trigg_self
                                       ({demux_slave[I].add[9],demux_slave[I].add[4:2]} == 4'b11_10) ||    // barrier_trigg_wait
                                       ({demux_slave[I].add[9],demux_slave[I].add[4:2]} == 4'b11_11)   ) ; // barrier_trigg_wait_clear
      // check if Core I wants to access hw barrier unit 
      assign demux_add_is_barr[I]  = ( ({demux_slave[I].add[9],demux_slave[I].add[4:2]} == 4'b10_00) ||
                                       ({demux_slave[I].add[9],demux_slave[I].add[4:2]} == 4'b10_01) ||
                                       ({demux_slave[I].add[9],demux_slave[I].add[4:2]} == 4'b10_10) ||
                                       ({demux_slave[I].add[9],demux_slave[I].add[4:2]} == 4'b10_11) ||
                                       ({demux_slave[I].add[9],demux_slave[I].add[4:2]} == 4'b11_00)   ) ; // hw barier unit
    end
  endgenerate


  generate
    for ( I = 0; I < NB_CORES; I++ ) begin : g_demux_int_bus_core_master
      // master->slave
      assign demux_int_bus_core_master[I].req    = demux_slaves_core_req[I];
      assign demux_int_bus_core_master[I].add    = demux_slave[I].add;
      assign demux_int_bus_core_master[I].we_n   = demux_slave[I].we_n;
      assign demux_int_bus_core_master[I].wdata  = demux_slave[I].wdata;

      assign demux_int_bus_core_master[I].id     = '0;
      assign demux_int_bus_core_master[I].be     = '1;
    end
  endgenerate

  generate
    for ( J = 0; J < NB_BARR; J++ ) begin : g_demux_int_bus_barrier_master
      
      // REQ generation
      for ( I = 0; I < NB_CORES; I++ ) assign demux_slv_bar_req_int_transp[J][I] = demux_slv_bar_req_int[I][J];

      ff1_loop #(
        .WIDTH(NB_CORES) )
      ff1_loop_i (
        .vector_i   ( demux_slv_bar_req_int_transp[J] ),
        .idx_bin_o  ( barr_arb_ff1[J] ),
        .no1_o      ( barr_arb_no1[J] )
      );

      assign barr_arb_sel[J] = barr_arb_no1[J] ? '0 : barr_arb_ff1[J];
      
      assign demux_int_bus_barrier_master[J].req    = ~barr_arb_no1[J];
      assign demux_int_bus_barrier_master[J].we_n    = demux_slave_we_n[barr_arb_sel[J]];
      assign demux_int_bus_barrier_master[J].add    = demux_slave_add[barr_arb_sel[J]];
      assign demux_int_bus_barrier_master[J].wdata  = demux_slave_wdata[barr_arb_sel[J]];
      assign demux_int_bus_barrier_master[J].id     = '0;
      assign demux_int_bus_barrier_master[J].be     = '1;

      // RESPONSE generation
      assign demux_int_bus_barrier_master_r_rdata[J] = demux_int_bus_barrier_master[J].r_rdata;

      for ( I = 0; I < NB_CORES; I++ ) assign demux_slave_gnt_barr[I][J] = (~barr_arb_no1[J]) && (barr_arb_ff1[J] == I);
      
    end
  endgenerate
  
  generate
    for ( I = 0; I < NB_CORES; I++ ) begin : g_demux_slave

      // make bus arrays slice selectable
      assign demux_slave_we_n[I]  = demux_slave[I].we_n;
      assign demux_slave_add[I]   = demux_slave[I].add;
      assign demux_slave_wdata[I] = demux_slave[I].wdata;

     
      assign demux_slave_aligned_access_err[I]      = (demux_slave[I].add[1:0] != 2'h0) || (demux_slave[I].be != 4'hF);

      assign demux_slave_core_buffer_ro_err[I]      = demux_slave[I].we_n ? 1'b0 : (demux_slave[I].add[9:8] == 2'b0) && 
                                                                                   ( demux_slave[I].add[5:2] == 4'b01_10 || // core_status
                                                                                     demux_slave[I].add[5:2] == 4'b01_11 || // core_buffer
                                                                                     demux_slave[I].add[5:2] == 4'b10_00 || // core_buffer_masked
                                                                                     demux_slave[I].add[5:2] == 4'b10_01 || // core_buffer_irq_masked
                                                                                     demux_slave[I].add[5:2] == 4'b11_10 || // core_event_wait
                                                                                     demux_slave[I].add[5:2] == 4'b11_11    // core_event_wait_clear
                                                                                     ) ? 1'b1 : 1'b0;
      assign demux_slave_core_hw_barr_ro_err[I]     = demux_slave[I].we_n ? 1'b0 : (demux_slave[I].add[9] == 1'b1) && 
                                                                                   ( demux_slave[I].add[4:2] == 3'b1_01 ||
                                                                                     demux_slave[I].add[4:2] == 3'b1_10 ||
                                                                                     demux_slave[I].add[4:2] == 3'b1_11    ) ? 1'b1 : 1'b0;
      assign demux_slave_core_trigg_ro_err[I]       = demux_slave[I].we_n ? 1'b0 : ( demux_slave[I].add[8:6] == 9'b1_01 ||
                                                                                     demux_slave[I].add[8:7] == 9'b1_1     ) ? 1'b1 : 1'b0;

      assign demux_slave_core_ro_err[I] = demux_slave_core_buffer_ro_err[I] | demux_slave_core_hw_barr_ro_err[I] | demux_slave_core_trigg_ro_err[I];

      assign demux_slave_hw_barr_ro_err[I]          = ( !demux_slave[I].we_n && demux_slave[I].add[9] == 1'b1 && demux_slave[I].add[4:2] == 3'b0_01 ) ||
                                                      (                         demux_slave[I].add[9] == 1'b1 && demux_slave[I].add[4:2] == 3'b0_10 );

      // decoding of IP select part of address in case of request, selection of correct gnt
      always_comb begin : p_demux_req_decoding

        demux_slv_bar_req_int[I] = '0;
  
        demux_slaves_core_req[I] = 1'b0;
        demux_slave_gnt_mux[I]   = 1'b0;
        demux_slave_reg_err[I]   = 1'b0;

        if ( demux_slave[I].req & !demux_slave_aligned_access_err[I]) begin
          
          // send request to private core unit, mux gnt back
          if ( demux_add_is_core[I] & !demux_slave_core_ro_err[I]) begin

            if (demux_slave[I].add[9]) begin // HW barrier

              if (NB_BARR == 1) begin
                if (demux_slave[I].add[8:5] == 'h0) begin
                  demux_slaves_core_req[I] = 1'b1;
                  demux_slave_gnt_mux[I]   = demux_int_bus_core_master[I].gnt;
                end else begin
                  demux_slave_gnt_mux[I] = 1'b1;
                  demux_slave_reg_err[I] = 1'b1;
                end
              end else begin
                if (demux_slave[I].add[8:5] < NB_BARR) begin
                  demux_slaves_core_req[I] = 1'b1;
                  demux_slave_gnt_mux[I]   = demux_int_bus_core_master[I].gnt;
                end else begin
                  demux_slave_gnt_mux[I] = 1'b1;
                  demux_slave_reg_err[I] = 1'b1;
                end
              end

            end else
            if (demux_slave[I].add[9:6] == 4'b0011) begin // mutexes

              if (NB_HW_MUT == 1) begin
                if (demux_slave[I].add[5:2] == 'h0) begin
                  demux_slaves_core_req[I] = 1'b1;
                  demux_slave_gnt_mux[I]   = demux_int_bus_core_master[I].gnt;
                end else begin
                  demux_slave_gnt_mux[I] = 1'b1;
                  demux_slave_reg_err[I] = 1'b1;
                end
              end else begin
                if (demux_slave[I].add[5:2] < NB_HW_MUT) begin
                  demux_slaves_core_req[I] = 1'b1;
                  demux_slave_gnt_mux[I]   = demux_int_bus_core_master[I].gnt;
                end else begin
                  demux_slave_gnt_mux[I] = 1'b1;
                  demux_slave_reg_err[I] = 1'b1;
                end
              end

            end else begin

              demux_slaves_core_req[I] = 1'b1;
              demux_slave_gnt_mux[I]   = demux_int_bus_core_master[I].gnt;
            
            end
          end

          // send request to correct barrier unit, mux gnt back
          else if ( demux_add_is_barr[I] & !demux_slave_hw_barr_ro_err[I]) begin // (Code below modified to fix INDEX_ILLEGAL reported by LINT tools)
            if (NB_BARR == 1) begin
              if (demux_slave[I].add[8:5] == 'h0) begin
                demux_slv_bar_req_int[I] = 1'b1;
                demux_slave_gnt_mux[I] = |demux_slave_gnt_barr[I];
              end else begin
                demux_slave_gnt_mux[I] = 1'b1;
                demux_slave_reg_err[I] = 1'b1;
              end
            end else begin
              if (demux_slave[I].add[8:5] < NB_BARR) begin
                demux_slv_bar_req_int[I][demux_slave[I].add[(LOG_NB_BARR+5)-1:5]] = 1'b1;
                demux_slave_gnt_mux[I] = |demux_slave_gnt_barr[I];
              end else begin
                demux_slave_gnt_mux[I] = 1'b1;
                demux_slave_reg_err[I] = 1'b1;
              end
            end
          end else begin
            demux_slave_gnt_mux[I] = 1'b1;
            demux_slave_reg_err[I] = 1'b1;
          end

        end else if ( demux_slave[I].req & (demux_slave_aligned_access_err[I] | demux_slave_core_ro_err[I] | demux_slave_hw_barr_ro_err[I]) ) begin
            demux_slave_gnt_mux[I] = 1'b1;
        end
      end // end for


      // delayed muxing of correct response
      always_comb begin : p_demux_response_delayed
    
        // default: silence response channel
        demux_slave[I].r_valid = 1'b0;
        demux_slave[I].r_opc   = 1'b0;
        demux_slave[I].r_rdata = '0;
    
        if ( demux_slave_req_del[I] && !demux_slave_aligned_access_err_del[I]  && !demux_slave_reg_err_del[I]) begin
          if ( (demux_add_is_core_del[I] && !demux_slave_core_ro_err_del[I]) || (demux_add_is_barr_del[I] && !demux_slave_hw_barr_ro_err_del[I]) )
            if ( ~demux_ip_sel_SP[I] ) begin
              demux_slave[I].r_valid = demux_int_bus_core_master[I].r_valid;
              demux_slave[I].r_rdata = demux_int_bus_core_master[I].r_rdata;
            end
            else begin
              demux_slave[I].r_valid = demux_slave_rvalid_barr[I];
              demux_slave[I].r_rdata = demux_int_bus_barrier_master_r_rdata[demux_barr_sel_SP[I]];
            end
          else begin
            demux_slave[I].r_valid = 1'b1;
            demux_slave[I].r_opc   = 1'b1;
          end
        end
        else if ( demux_slave_req_del[I] && (demux_slave_aligned_access_err_del[I] || demux_slave_reg_err_del[I] || demux_slave_core_ro_err_del[I] || demux_slave_hw_barr_ro_err_del[I]) ) begin
            demux_slave[I].r_valid = 1'b1;
            demux_slave[I].r_opc   = 1'b1;
        end
      end

      onehot_to_bin #(.ONEHOT_WIDTH(NB_BARR)) demux_barr_id_i (.onehot(demux_slave_gnt_barr[I]), .bin(demux_slave_gnt_barr_bin[I]));

      // delayed signals to compute correct response
      always_ff @(posedge clk_i, negedge rst_ni)
      begin
        if (~rst_ni)
        begin
          demux_slave_req_del[I] <= 1'b0;
          demux_slave_gnt_mux_del[I] <= 1'b0;

          demux_ip_sel_SP[I]     <= 1'b0;
          demux_barr_sel_SP[I]   <= '0;

          demux_slave_rvalid_barr[I] <= 1'b0;

          demux_slave_reg_err_del[I] <= 1'b0;
          demux_slave_aligned_access_err_del[I] <= 1'b0;
          demux_slave_core_buffer_ro_err_del[I] <= 1'b0;
          demux_slave_core_hw_barr_ro_err_del[I] <= 1'b0;
          demux_slave_hw_barr_ro_err_del[I] <= 1'b0;
          demux_slave_core_trigg_ro_err_del[I] <= 1'b0;
          demux_slave_core_ro_err_del[I] <= 1'b0;

        end
        else
        begin
          demux_slave_req_del[I] <= demux_slave[I].req;
          demux_slave_gnt_mux_del[I] <= demux_slave_gnt_mux[I];
          demux_slave_reg_err_del[I] <= demux_slave_reg_err[I];
          demux_slave_aligned_access_err_del[I] <= demux_slave_aligned_access_err[I];
          demux_slave_core_buffer_ro_err_del[I] <= demux_slave_core_buffer_ro_err[I];
          demux_slave_core_hw_barr_ro_err_del[I] <= demux_slave_core_hw_barr_ro_err[I];
          demux_slave_hw_barr_ro_err_del[I] <= demux_slave_hw_barr_ro_err[I];
          demux_slave_core_trigg_ro_err_del[I] <= demux_slave_core_trigg_ro_err[I];
          demux_slave_core_ro_err_del[I] <= demux_slave_core_ro_err[I];
          if ( demux_slave_update[I] ) begin
            demux_ip_sel_SP[I]    <= ~demux_add_is_core[I];
            demux_barr_sel_SP[I]  <= demux_slave_gnt_barr_bin[I];
            demux_slave_rvalid_barr[I] <= |demux_slave_gnt_barr[I];
          end
        end
      end
    end
  endgenerate



  //*************************************************************//
  //                                                             //
  //        ██╗███╗   ██╗████████╗███████╗██████╗  ██████╗       //
  //        ██║████╗  ██║╚══██╔══╝██╔════╝██╔══██╗██╔════╝       //
  //        ██║██╔██╗ ██║   ██║   █████╗  ██████╔╝██║            //
  //        ██║██║╚██╗██║   ██║   ██╔══╝  ██╔══██╗██║            //
  //        ██║██║ ╚████║   ██║   ███████╗██║  ██║╚██████╗       //
  //        ╚═╝╚═╝  ╚═══╝   ╚═╝   ╚══════╝╚═╝  ╚═╝ ╚═════╝       //
  //                                                             //
  //*************************************************************//



  // response channel for interconnect plug
  logic [5:0] interc_ip_sel_SP;
  logic [5:0] interc_ip_sel_SN;
  logic       speriph_slave_req_del;
  logic       speriph_slave_update;
  logic       speriph_slave_gnt_mux;
  logic       speriph_slave_gnt_mux_del;
  logic       speriph_slave_aligned_access_err;
  logic       speriph_slave_aligned_access_err_del;
  logic       speriph_slave_hw_barr_ro_err;
  logic       speriph_slave_hw_barr_ro_err_del;
  logic       speriph_slave_core_buffer_ro_err;
  logic       speriph_slave_core_buffer_ro_err_del;
  logic       speriph_slave_soc_ro_err;
  logic       speriph_slave_soc_ro_err_del;
  logic       speriph_slave_reg_err;
  logic       speriph_slave_reg_err_del;

  logic [NB_CORES+NB_BARR+2:0] interc_slaves_req;

  // helper arrays to work around sv dynamic bus index select limitation
  logic [NB_CORES-1:0][31:0] periph_int_bus_core_rdata;
  logic [NB_BARR-1:0][31:0]  periph_int_bus_barr_rdata;
  logic [NB_CORES-1:0]       periph_int_bus_core_rvalid;
  logic [NB_BARR-1:0]        periph_int_bus_barr_rvalid;
  logic [NB_CORES-1:0]       periph_int_bus_core_gnt;
  logic [NB_BARR-1:0]        periph_int_bus_barr_gnt;


  assign interc_ip_sel_SN = speriph_slave.add[10:5];

  assign speriph_slave_aligned_access_err = (speriph_slave.add[1:0] != '0) || (speriph_slave.be != 4'hF);

  assign speriph_slave_core_buffer_ro_err = speriph_slave.we_n ? 1'b0 : ( speriph_slave.add[5:2] == 4'b01_10 || // core_status
                                                                          speriph_slave.add[5:2] == 4'b01_11 || // core_buffer
                                                                          speriph_slave.add[5:2] == 4'b10_00 || // core_buffer_masked
                                                                          speriph_slave.add[5:2] == 4'b10_01    // core_buffer_irq_masked
                                                                          ) ? 1'b1 : 1'b0;

  assign speriph_slave_hw_barr_ro_err     = ( !speriph_slave.we_n && speriph_slave.add[3:2] == 2'b01 )    ? 1'b1 : 1'b0;

  assign speriph_slave_soc_ro_err         =   (!speriph_slave.we_n && speriph_slave.add[10:8]   == 3'h7     );


  // activation condition for speriph slave responses
  assign speriph_slave_update = ( (speriph_slave.req & ~speriph_slave_req_del) ||
                                  (~speriph_slave.req & speriph_slave_req_del) ||
                                  (speriph_slave.req & speriph_slave_gnt_mux)  ||
                                  (speriph_slave_req_del & speriph_slave_gnt_mux_del));

  // broadcast master->slave signals with exception of req
  generate
    for ( I = 0; I < NB_CORES+NB_BARR+3; I++ ) begin : g_periph_int_bus_master
      assign periph_int_bus_master[I].wdata = speriph_slave.wdata;
      assign periph_int_bus_master[I].add   = speriph_slave.add;
      assign periph_int_bus_master[I].we_n   = speriph_slave.we_n;
      assign periph_int_bus_master[I].be    = '1;
      assign periph_int_bus_master[I].id    = '0;
      assign periph_int_bus_master[I].req   = interc_slaves_req[I];
    end
  endgenerate

  // assign slave->master signals
  generate
    for ( I = 0; I < NB_CORES; I++ ) begin : g_periph_int_bus_core
      assign periph_int_bus_core_rdata[I]  = periph_int_bus_master[I].r_rdata;
      assign periph_int_bus_core_rvalid[I] = periph_int_bus_master[I].r_valid;
      assign periph_int_bus_core_gnt[I]    = periph_int_bus_master[I].gnt;
    end
    for ( I = 0; I < NB_BARR; I++ ) begin : g_periph_int_bus_barr
      assign periph_int_bus_barr_rdata[I]  = periph_int_bus_master[NB_CORES+I].r_rdata;
      assign periph_int_bus_barr_rvalid[I] = periph_int_bus_master[NB_CORES+I].r_valid;
      assign periph_int_bus_barr_gnt[I]    = periph_int_bus_master[NB_CORES+I].gnt;
    end
  endgenerate

  // assign muxed slave->master gnt
  assign speriph_slave.gnt   = speriph_slave_gnt_mux;

  // decoding of IP select part of address in case of request, selection of correct gnt
  always_comb begin : p_interc_req_decoding
    interc_slaves_req     = '0;
    speriph_slave_gnt_mux = 1'b0;
    speriph_slave_reg_err = 1'h0;

    if (speriph_slave.req) begin
      case ( speriph_slave.add[10:7])
        4'b0000, 4'b0001, 4'b0010, 4'b0011, 4'b0100, 4'b0101, 4'b0110, 4'b0111: begin  // core units - each 0x40 (16 regs) long, [9:6] decides about which unit (Code below modified to fix INDEX_ILLEGAL reported by LINT tools)
          if (NB_CORES == 1) begin
            if (!speriph_slave_aligned_access_err && !speriph_slave_core_buffer_ro_err && speriph_slave.add[9:6] == 'h0 && speriph_slave.add[5:3] != 3'h7) begin
              interc_slaves_req = 1'b1;
              speriph_slave_gnt_mux = periph_int_bus_core_gnt;
            end else begin
              speriph_slave_gnt_mux = 1'h1;
              speriph_slave_reg_err = 1'h1;
            end
          end else begin
            if (!speriph_slave_aligned_access_err && !speriph_slave_core_buffer_ro_err && speriph_slave.add[9:6] < NB_CORES && speriph_slave.add[5:3] != 'h7) begin
              interc_slaves_req[speriph_slave.add[LOG_NB_CORES+5:6]] = 1'b1;
              speriph_slave_gnt_mux = periph_int_bus_core_gnt[speriph_slave.add[LOG_NB_CORES+5:6]];
            end else begin
              speriph_slave_gnt_mux = 1'h1;
              speriph_slave_reg_err = 1'h1;
            end
          end
        end
        4'b1000, 4'b1001, 4'b1010, 4'b1011: begin  // hw barrier - each 0x20 (8 regs) long, [8:5] decides about which unit (Code below modified to fix INDEX_ILLEGAL reported by LINT tools)
          if (NB_BARR == 1) begin
            if (!speriph_slave_aligned_access_err && !speriph_slave_hw_barr_ro_err && speriph_slave.add[8:5] == 'h0 && (speriph_slave.add[4:2] != 3'b111 && speriph_slave.add[4:2] != 3'b101 && speriph_slave.add[4:2] != 3'b110)) begin
              interc_slaves_req = 1'b1;
              speriph_slave_gnt_mux = periph_int_bus_barr_gnt;
            end else begin
              speriph_slave_gnt_mux = 1'h1;
              speriph_slave_reg_err = 1'h1;
            end
          end else begin
            if (!speriph_slave_aligned_access_err && !speriph_slave_hw_barr_ro_err && speriph_slave.add[8:5] < NB_BARR && (speriph_slave.add[4:2] != 3'b111 && speriph_slave.add[4:2] != 3'b101 && speriph_slave.add[3:2] != 2'b10)) begin
              interc_slaves_req[NB_CORES+speriph_slave.add[LOG_NB_BARR+4:5]] = 1'b1;
              speriph_slave_gnt_mux = periph_int_bus_barr_gnt[speriph_slave.add[LOG_NB_BARR+4:5]];
            end else begin
              speriph_slave_gnt_mux = 1'h1;
              speriph_slave_reg_err = 1'h1;
            end
          end
        end
        4'b1100 : begin // external sw event triggering
          if (!speriph_slave_aligned_access_err && speriph_slave.add[6:2] < NB_SW_EVT) begin
            interc_slaves_req[NB_CORES+NB_BARR] = 1'b1;
            speriph_slave_gnt_mux = periph_int_bus_master[NB_CORES+NB_BARR].gnt;
          end else begin
            speriph_slave_gnt_mux = 1'h1;
            speriph_slave_reg_err = 1'h1;
          end
        end
        4'b1110: begin // soc event FIFO
          if (!speriph_slave_aligned_access_err && !speriph_slave_soc_ro_err && speriph_slave.add[6:0] == 'h0) begin
            interc_slaves_req[NB_CORES+NB_BARR+1] = 1'b1;
            speriph_slave_gnt_mux = periph_int_bus_master[NB_CORES+NB_BARR+1].gnt;
          end else begin
            speriph_slave_gnt_mux = 1'h1;
            speriph_slave_reg_err = 1'h1;
          end

        end
        default: begin
          speriph_slave_gnt_mux = 1'h1;
          speriph_slave_reg_err = 1'h1;
        end
      endcase
    end
  end

  // delayed muxing of correct response
  always_comb begin : p_interc_response_delayed

    // default: silence response channel
    speriph_slave.r_valid = '0;
    speriph_slave.r_opc   = '0;
    speriph_slave.r_rdata = '0;

    if ( speriph_slave_req_del && !speriph_slave_aligned_access_err_del && !speriph_slave_reg_err_del ) begin
      case ( interc_ip_sel_SP[5:2] )
        4'b0000, 4'b0001, 4'b0010, 4'b0011, 4'b0100, 4'b0101, 4'b0110, 4'b0111: begin // core units (Code below modified to fix INDEX_ILLEGAL reported by LINT tools)
          if (NB_CORES == 1) begin
            if (interc_ip_sel_SP[4:1] == 'h0 && !speriph_slave_core_buffer_ro_err_del) begin
              speriph_slave.r_valid = periph_int_bus_core_rvalid;
              speriph_slave.r_rdata = periph_int_bus_core_rdata;
            end else begin
              speriph_slave.r_valid = 1'b1;
              speriph_slave.r_opc   = 1'b1;
            end
          end else begin
            if (interc_ip_sel_SP[4:1] < NB_CORES && !speriph_slave_core_buffer_ro_err_del) begin
              speriph_slave.r_valid = periph_int_bus_core_rvalid[interc_ip_sel_SP[LOG_NB_CORES:1]];
              speriph_slave.r_rdata = periph_int_bus_core_rdata[interc_ip_sel_SP[LOG_NB_CORES:1]];
            end else begin
              speriph_slave.r_valid = 1'b1;
              speriph_slave.r_opc   = 1'b1;
            end
          end
        end
        4'b1000, 4'b1001, 4'b1010, 4'b1011: begin // barrier units (Code below modified to fix INDEX_ILLEGAL reported by LINT tools)
          if (NB_BARR == 1) begin
            if (interc_ip_sel_SP[3:0] == 'h0 && !speriph_slave_hw_barr_ro_err_del) begin
              speriph_slave.r_valid = periph_int_bus_barr_rvalid;
              speriph_slave.r_rdata = periph_int_bus_barr_rdata;
            end else begin
              speriph_slave.r_valid = 1'b1;
              speriph_slave.r_opc   = 1'b1;
            end
          end else begin
            if (interc_ip_sel_SP[3:0] < NB_BARR && !speriph_slave_hw_barr_ro_err_del) begin
              speriph_slave.r_valid = periph_int_bus_barr_rvalid[interc_ip_sel_SP[LOG_NB_BARR-1:0]];
              speriph_slave.r_rdata = periph_int_bus_barr_rdata[interc_ip_sel_SP[LOG_NB_BARR-1:0]];
            end else begin
              speriph_slave.r_valid = 1'b1;
              speriph_slave.r_opc   = 1'b1;
            end
          end
        end
        4'b1100, 4'b1101: begin // external sw event trigger
          speriph_slave.r_valid = periph_int_bus_master[NB_CORES+NB_BARR].r_valid;
          speriph_slave.r_rdata = periph_int_bus_master[NB_CORES+NB_BARR].r_rdata;
        end
        4'b1110: begin // soc event FIFO
          if (!speriph_slave_soc_ro_err_del) begin
            speriph_slave.r_valid = periph_int_bus_master[NB_CORES+NB_BARR+1].r_valid;
            speriph_slave.r_rdata = periph_int_bus_master[NB_CORES+NB_BARR+1].r_rdata;
          end else begin
            speriph_slave.r_valid = 1'b1;
            speriph_slave.r_opc   = 1'b1;
          end
        end
        default: begin
          speriph_slave.r_valid = 1'b1;
          speriph_slave.r_opc   = 1'b1;
        end
      endcase
    end
    else if ( speriph_slave_req_del && ( speriph_slave_aligned_access_err_del || speriph_slave_reg_err_del || speriph_slave_hw_barr_ro_err_del || speriph_slave_core_buffer_ro_err_del || speriph_slave_soc_ro_err_del) ) begin
      speriph_slave.r_valid = 1'b1;
      speriph_slave.r_opc   = 1'b1;
    end
  end


  // delay for interconnect signals
  always_ff @(posedge clk_i, negedge rst_ni)
  begin
    if (~rst_ni) begin
      speriph_slave.r_id                   <= '0;
      interc_ip_sel_SP                     <= '0;
      speriph_slave_req_del                <= 1'b0;
      speriph_slave_gnt_mux_del            <= 1'b0;
      speriph_slave_reg_err_del            <= 1'b0;
      speriph_slave_aligned_access_err_del <= '0;
      speriph_slave_hw_barr_ro_err_del     <= 1'b0;
      speriph_slave_soc_ro_err_del         <= 1'b0;
      speriph_slave_core_buffer_ro_err_del <= 1'b0;
      demux_add_is_core_del                <= '0;
      demux_add_is_barr_del                <= '0;
    end
    else
    begin
      speriph_slave_req_del                <= speriph_slave.req;
      speriph_slave_gnt_mux_del            <= speriph_slave_gnt_mux;
      speriph_slave_reg_err_del            <= speriph_slave_reg_err;
      speriph_slave_aligned_access_err_del <= speriph_slave_aligned_access_err;
      speriph_slave_hw_barr_ro_err_del     <= speriph_slave_hw_barr_ro_err;
      speriph_slave_core_buffer_ro_err_del <= speriph_slave_core_buffer_ro_err;
      speriph_slave_soc_ro_err_del         <= speriph_slave_soc_ro_err;
      demux_add_is_core_del                <= demux_add_is_core;
      demux_add_is_barr_del                <= demux_add_is_barr;
      if ( speriph_slave_update )
      begin
        speriph_slave.r_id <= speriph_slave.id;
        interc_ip_sel_SP   <= interc_ip_sel_SN;
      end
    end
  end

endmodule // event_unit_interface_mux
