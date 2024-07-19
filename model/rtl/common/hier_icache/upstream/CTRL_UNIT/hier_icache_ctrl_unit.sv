// ========================================================================== //
//                           COPYRIGHT NOTICE                                 //
// Copyright 2019 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License. You may obtain a copy of the License at
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
// Create Date:    18/08/2014                                                    //
// Design Name:    icache_ctrl_unit                                              //
// Module Name:    icache_ctrl_unit                                              //
// Project Name:   ULPSoC                                                        //
// Language:       SystemVerilog                                                 //
//                                                                               //
// Description:    ICACHE control Unit, used to enable/disable icache banks      //
//                 flush operations, and to debug the status og cache banks      //
//                                                                               //
// Revision:                                                                     //
// Revision v0.1 - File Created                                                  //
//                                                                               //
//                                                                               //
//                                                                               //
//                                                                               //
//                                                                               //
//                                                                               //
// ============================================================================= //

// Prefetch is disabled in hardware
// To re-enable prefetch, check all comment with tag #prefetch
import hier_icache_pkg::*;

module hier_icache_ctrl_unit
#(
    parameter  int NB_CACHE_BANKS = 4,
    parameter  int NB_CORES       = 9,
    parameter  int ID_WIDTH       = 5
)
(
    input logic                                 clk_i,
    input logic                                 rst_ni,

    // Exploded Interface --> PERIPHERAL INTERFACE
    input  logic                                 speriph_slave_req_i,
    input  logic [31:0]                          speriph_slave_addr_i,
    input  logic                                 speriph_slave_we_n_i,
    input  logic [31:0]                          speriph_slave_wdata_i,
    input  logic [3:0]                           speriph_slave_be_i,
    output logic                                 speriph_slave_gnt_o,
    input  logic [ID_WIDTH-1:0]                  speriph_slave_id_i,
    output logic                                 speriph_slave_r_valid_o,
    output logic                                 speriph_slave_r_opc_o,
    output logic [ID_WIDTH-1:0]                  speriph_slave_r_id_o,
    output logic [31:0]                          speriph_slave_r_rdata_o,


    output logic [NB_CORES-1:0]                  L1_icache_bypass_req_o,
    input  logic [NB_CORES-1:0]                  L1_icache_bypass_ack_i,
    output logic [NB_CORES-1:0]                  L1_icache_flush_req_o,
    input  logic [NB_CORES-1:0]                  L1_icache_flush_ack_i,
    output logic [NB_CORES-1:0]                  L1_icache_sel_flush_req_o,
    output logic [31:0]                          L1_icache_sel_flush_addr_o,
    input  logic [NB_CORES-1:0]                  L1_icache_sel_flush_ack_i,


    output logic [NB_CACHE_BANKS-1:0]            L2_icache_enable_req_o,
    input  logic [NB_CACHE_BANKS-1:0]            L2_icache_enable_ack_i,
    output logic [NB_CACHE_BANKS-1:0]            L2_icache_disable_req_o,
    input  logic [NB_CACHE_BANKS-1:0]            L2_icache_disable_ack_i,
    output logic [NB_CACHE_BANKS-1:0]            L2_icache_flush_req_o,
    input  logic [NB_CACHE_BANKS-1:0]            L2_icache_flush_ack_i,
    output logic [NB_CACHE_BANKS-1:0]            L2_icache_sel_flush_req_o,
    output logic [31:0]                          L2_icache_sel_flush_addr_o,
    input  logic [NB_CACHE_BANKS-1:0]            L2_icache_sel_flush_ack_i,

    output logic [NB_CORES-1:0]                  enable_l1_l15_prefetch_o,

    // L1 Counters
    input logic [NB_CORES-1:0] [31:0]                 L1_hit_count_i,
    input logic [NB_CORES-1:0] [31:0]                 L1_trans_count_i,
    input logic [NB_CORES-1:0] [31:0]                 L1_miss_count_i,
    input logic [NB_CORES-1:0] [31:0]                 L1_cong_count_i,

    output logic [NB_CORES-1:0]                       L1_clear_regs_o,
    output logic [NB_CORES-1:0]                       L1_enable_regs_o,

    // L2 Counters
    input logic [NB_CACHE_BANKS-1:0] [31:0]           L2_hit_count_i,
    input logic [NB_CACHE_BANKS-1:0] [31:0]           L2_trans_count_i,
    input logic [NB_CACHE_BANKS-1:0] [31:0]           L2_miss_count_i,

    output logic [NB_CACHE_BANKS-1:0]                 L2_clear_regs_o,
    output logic [NB_CACHE_BANKS-1:0]                 L2_enable_regs_o

);

   //logic [NB_CACHE_BANKS+NB_CORES-1:0]              r_enable_icache;
   logic                                              r_enable_icache;
   logic [NB_CACHE_BANKS+NB_CORES-1:0]                r_flush_icache;
   logic [31:0]                                       r_sel_flush_icache;

   logic [NB_CACHE_BANKS+NB_CORES-1:0]                r_clear_cnt;
   //logic [NB_CACHE_BANKS+NB_CORES-1:0]                r_enable_cnt;
   logic                                              r_enable_cnt;

   logic [31:0]                                       s_slave_r_rdata;

    int unsigned  i,j,k,x,y;

    localparam BASE_PERF_CNT = 8;


    // State of the main FSM
    enum logic [2:0] { IDLE, ENABLE_ICACHE,  DISABLE_ICACHE, FLUSH_ICACHE_CHECK, SEL_FLUSH_ICACHE, CLEAR_STAT_REGS, ENABLE_STAT_REGS } CS, NS;

    // Logic to Track the received acks on L1 PRI
    logic [NB_CORES-1:0]                 L1_mask_bypass_req_CS;
    logic [NB_CORES-1:0]                 L1_mask_bypass_req_NS;
    logic [NB_CORES-1:0]                 L1_mask_flush_req_CS;
    logic [NB_CORES-1:0]                 L1_mask_flush_req_NS;
    logic [NB_CORES-1:0]                 L1_mask_sel_flush_req_CS;
    logic [NB_CORES-1:0]                 L1_mask_sel_flush_req_NS;

    // Logic to Track the received acks on L2 SH
    logic [NB_CACHE_BANKS-1:0]           L2_mask_enable_req_CS;
    logic [NB_CACHE_BANKS-1:0]           L2_mask_enable_req_NS;
    logic [NB_CACHE_BANKS-1:0]           L2_mask_disable_req_CS;
    logic [NB_CACHE_BANKS-1:0]           L2_mask_disable_req_NS;
    logic [NB_CACHE_BANKS-1:0]           L2_mask_flush_req_CS;
    logic [NB_CACHE_BANKS-1:0]           L2_mask_flush_req_NS;
    logic [NB_CACHE_BANKS-1:0]           L2_mask_sel_flush_req_CS;
    logic [NB_CACHE_BANKS-1:0]           L2_mask_sel_flush_req_NS;

    // Internal FSM signals --> responses
    logic                                 is_write;
    logic                                 deliver_response;
    logic                                 clear_flush_reg;

    logic [15:0][3:0][31:0]               perf_cnt_L1;
    logic [15:0][2:0][31:0]               perf_cnt_L2;

    logic                                 is_write_error, is_read_error;
    logic                                 is_write_response;


     genvar index;



   always_comb
   begin : p_register_bind_out
      //L1_icache_bypass_req_o     =  ~r_enable_icache[NB_CORES-1:0];
      L1_icache_bypass_req_o     =  {NB_CORES{~r_enable_icache}};
      L1_icache_sel_flush_addr_o =   r_sel_flush_icache;

      //L2_icache_enable_req_o     =   r_enable_icache[NB_CACHE_BANKS+NB_CORES-1:NB_CORES];
      //L2_icache_disable_req_o    =  ~r_enable_icache[NB_CACHE_BANKS+NB_CORES-1:NB_CORES];
      L2_icache_enable_req_o     =  {NB_CACHE_BANKS{ r_enable_icache}};
      L2_icache_disable_req_o    =  {NB_CACHE_BANKS{~r_enable_icache}};

      L2_icache_sel_flush_addr_o =   r_sel_flush_icache;

      //L1_enable_regs_o           =   r_enable_cnt[NB_CORES-1:0];
      //L2_enable_regs_o           =   r_enable_cnt[NB_CACHE_BANKS+NB_CORES-1:NB_CORES];
      L1_enable_regs_o           =   {NB_CORES      {r_enable_cnt}};
      L2_enable_regs_o           =   {NB_CACHE_BANKS{r_enable_cnt}};
   end



   logic [31:0] global_L1_hit;
   logic [31:0] global_L1_trans;
   logic [31:0] global_L1_miss;
   logic [31:0] global_L1_cong;

   logic [31:0] global_L2_hit;
   logic [31:0] global_L2_trans;
   logic [31:0] global_L2_miss;


    always_comb
    begin : p_global_hit
        global_L1_hit   = '0;
        global_L1_trans = '0;
        global_L1_miss  = '0;
        global_L1_cong  = '0;

        global_L2_hit   = '0;
        global_L2_trans = '0;
        global_L2_miss  = '0;

        for(int unsigned p=0; p<NB_CORES; p++)
        begin
            global_L1_hit   = global_L1_hit   + L1_hit_count_i[p];
            global_L1_trans = global_L1_trans + L1_trans_count_i[p];
            global_L1_miss  = global_L1_miss  + L1_miss_count_i[p];
            global_L1_cong  = global_L1_cong  + L1_cong_count_i[p];
        end

        for(int unsigned p=0; p<NB_CACHE_BANKS; p++)
        begin
            global_L2_hit   = global_L2_hit   + L2_hit_count_i[p];
            global_L2_trans = global_L2_trans + L2_trans_count_i[p];
            global_L2_miss  = global_L2_miss  + L2_miss_count_i[p];
        end
    end


generate


   logic [31:0] perf_cnt_enable;

     assign perf_cnt_enable = { {(32-NB_CACHE_BANKS-NB_CORES){1'b0}}, {r_enable_cnt} };
     for(index=0; index<16; index++)
     begin : g_perf_cnt_binding

        always_comb
        begin


          if(index<NB_CORES)
          begin
              perf_cnt_L1[index][0] = L1_hit_count_i   [index];
              perf_cnt_L1[index][1] = L1_trans_count_i [index];
              perf_cnt_L1[index][2] = L1_miss_count_i  [index];
              perf_cnt_L1[index][3] = L1_cong_count_i  [index];
          end
          else
          begin
              perf_cnt_L1[index][0] = 32'hBAD_ACCE5;
              perf_cnt_L1[index][1] = 32'hBAD_ACCE5;
              perf_cnt_L1[index][2] = 32'hBAD_ACCE5;
              perf_cnt_L1[index][3] = 32'hBAD_ACCE5;
          end

        end


        always_comb
        begin

          if(index<NB_CACHE_BANKS)
          begin
              perf_cnt_L2[index][0] = L2_hit_count_i   [index];
              perf_cnt_L2[index][1] = L2_trans_count_i [index];
              perf_cnt_L2[index][2] = L2_miss_count_i  [index];
          end
          else
          begin
              perf_cnt_L2[index][0] = 32'hBAD_ACCE5;
              perf_cnt_L2[index][1] = 32'hBAD_ACCE5;
              perf_cnt_L2[index][2] = 32'hBAD_ACCE5;
          end

        end


     end //~for(index=0; index<16; index++)

     always_comb begin : read_data_
        s_slave_r_rdata = '0;
        case(speriph_slave_addr_i[8:2])
          0:   begin s_slave_r_rdata       = { {(31){1'b0}}, {r_enable_icache}     }; end
          1:   begin s_slave_r_rdata       = { {(31){1'b0}}, {r_flush_icache}      }; end
          3:   begin s_slave_r_rdata       = r_sel_flush_icache; end


          // Clear and start
          5:   begin s_slave_r_rdata       = perf_cnt_enable;            end
          7:   begin s_slave_r_rdata       = enable_l1_l15_prefetch_o;   end
          // BASE_PERF_CNT = 8
          (BASE_PERF_CNT+0):   begin s_slave_r_rdata       = 32'hF1CA_B01A ;  end
          (BASE_PERF_CNT+1):   begin s_slave_r_rdata       = 32'hF1CA_B01A ;  end
          (BASE_PERF_CNT+2):   begin s_slave_r_rdata       = 32'hF1CA_B01A ;  end
          (BASE_PERF_CNT+3):   begin s_slave_r_rdata       = 32'hF1CA_B01A ;  end

          (BASE_PERF_CNT+4):   begin s_slave_r_rdata       = global_L1_hit;   end
          (BASE_PERF_CNT+5):   begin s_slave_r_rdata       = global_L1_trans; end
          (BASE_PERF_CNT+6):   begin s_slave_r_rdata       = global_L1_miss;  end
          (BASE_PERF_CNT+7):   begin s_slave_r_rdata       = global_L1_cong;  end

          (BASE_PERF_CNT+8):   begin s_slave_r_rdata       = global_L2_hit;   end
          (BASE_PERF_CNT+9):   begin s_slave_r_rdata       = global_L2_trans; end
          (BASE_PERF_CNT+10):  begin s_slave_r_rdata       = global_L2_miss;  end


          (BASE_PERF_CNT+12):  begin s_slave_r_rdata       = perf_cnt_L1[0][0];  end
          (BASE_PERF_CNT+13):  begin s_slave_r_rdata       = perf_cnt_L1[0][1];  end
          (BASE_PERF_CNT+14):  begin s_slave_r_rdata       = perf_cnt_L1[0][2];  end
          (BASE_PERF_CNT+15):  begin s_slave_r_rdata       = perf_cnt_L1[0][3];  end

          (BASE_PERF_CNT+16):  begin s_slave_r_rdata       = perf_cnt_L1[1][0];  end
          (BASE_PERF_CNT+17):  begin s_slave_r_rdata       = perf_cnt_L1[1][1];  end
          (BASE_PERF_CNT+18):  begin s_slave_r_rdata       = perf_cnt_L1[1][2];  end
          (BASE_PERF_CNT+19):  begin s_slave_r_rdata       = perf_cnt_L1[1][3];  end

          (BASE_PERF_CNT+20):  begin s_slave_r_rdata       = perf_cnt_L1[2][0];  end
          (BASE_PERF_CNT+21):  begin s_slave_r_rdata       = perf_cnt_L1[2][1];  end
          (BASE_PERF_CNT+22):  begin s_slave_r_rdata       = perf_cnt_L1[2][2];  end
          (BASE_PERF_CNT+23):  begin s_slave_r_rdata       = perf_cnt_L1[2][3];  end

          (BASE_PERF_CNT+24):  begin s_slave_r_rdata       = perf_cnt_L1[3][0];  end
          (BASE_PERF_CNT+25):  begin s_slave_r_rdata       = perf_cnt_L1[3][1];  end
          (BASE_PERF_CNT+26):  begin s_slave_r_rdata       = perf_cnt_L1[3][2];  end
          (BASE_PERF_CNT+27):  begin s_slave_r_rdata       = perf_cnt_L1[3][3];  end

          (BASE_PERF_CNT+28):  begin s_slave_r_rdata       = perf_cnt_L1[4][0];  end
          (BASE_PERF_CNT+29):  begin s_slave_r_rdata       = perf_cnt_L1[4][1];  end
          (BASE_PERF_CNT+30):  begin s_slave_r_rdata       = perf_cnt_L1[4][2];  end
          (BASE_PERF_CNT+31):  begin s_slave_r_rdata       = perf_cnt_L1[4][3];  end

          (BASE_PERF_CNT+32):  begin s_slave_r_rdata       = perf_cnt_L1[5][0];  end
          (BASE_PERF_CNT+33):  begin s_slave_r_rdata       = perf_cnt_L1[5][1];  end
          (BASE_PERF_CNT+34):  begin s_slave_r_rdata       = perf_cnt_L1[5][2];  end
          (BASE_PERF_CNT+35):  begin s_slave_r_rdata       = perf_cnt_L1[5][3];  end

          (BASE_PERF_CNT+36):  begin s_slave_r_rdata       = perf_cnt_L1[6][0];  end
          (BASE_PERF_CNT+37):  begin s_slave_r_rdata       = perf_cnt_L1[6][1];  end
          (BASE_PERF_CNT+38):  begin s_slave_r_rdata       = perf_cnt_L1[6][2];  end
          (BASE_PERF_CNT+39):  begin s_slave_r_rdata       = perf_cnt_L1[6][3];  end

          (BASE_PERF_CNT+40):  begin s_slave_r_rdata       = perf_cnt_L1[7][0];  end
          (BASE_PERF_CNT+41):  begin s_slave_r_rdata       = perf_cnt_L1[7][1];  end
          (BASE_PERF_CNT+42):  begin s_slave_r_rdata       = perf_cnt_L1[7][2];  end
          (BASE_PERF_CNT+43):  begin s_slave_r_rdata       = perf_cnt_L1[7][3];  end

          (BASE_PERF_CNT+44):  begin s_slave_r_rdata       = perf_cnt_L2[0][0]; end
          (BASE_PERF_CNT+45):  begin s_slave_r_rdata       = perf_cnt_L2[0][1]; end
          (BASE_PERF_CNT+46):  begin s_slave_r_rdata       = perf_cnt_L2[0][2]; end

          (BASE_PERF_CNT+47):  begin s_slave_r_rdata       = perf_cnt_L2[1][0]; end
          (BASE_PERF_CNT+48):  begin s_slave_r_rdata       = perf_cnt_L2[1][1]; end
          (BASE_PERF_CNT+49):  begin s_slave_r_rdata       = perf_cnt_L2[1][2]; end

          (BASE_PERF_CNT+50):  begin s_slave_r_rdata       = perf_cnt_L2[2][0]; end
          (BASE_PERF_CNT+51):  begin s_slave_r_rdata       = perf_cnt_L2[2][1]; end
          (BASE_PERF_CNT+52):  begin s_slave_r_rdata       = perf_cnt_L2[2][2]; end

          (BASE_PERF_CNT+53):  begin s_slave_r_rdata       = perf_cnt_L2[3][0]; end
          (BASE_PERF_CNT+54):  begin s_slave_r_rdata       = perf_cnt_L2[3][1]; end
          (BASE_PERF_CNT+55):  begin s_slave_r_rdata       = perf_cnt_L2[3][2]; end

          (BASE_PERF_CNT+56):  begin s_slave_r_rdata       = perf_cnt_L2[4][0]; end
          (BASE_PERF_CNT+57):  begin s_slave_r_rdata       = perf_cnt_L2[4][1]; end
          (BASE_PERF_CNT+58):  begin s_slave_r_rdata       = perf_cnt_L2[4][2]; end

          (BASE_PERF_CNT+59):  begin s_slave_r_rdata       = perf_cnt_L2[5][0]; end
          (BASE_PERF_CNT+60):  begin s_slave_r_rdata       = perf_cnt_L2[5][1]; end
          (BASE_PERF_CNT+61):  begin s_slave_r_rdata       = perf_cnt_L2[5][2]; end

          (BASE_PERF_CNT+62):  begin s_slave_r_rdata       = perf_cnt_L2[6][0]; end
          (BASE_PERF_CNT+63):  begin s_slave_r_rdata       = perf_cnt_L2[6][1]; end
          (BASE_PERF_CNT+64):  begin s_slave_r_rdata       = perf_cnt_L2[6][2]; end

          (BASE_PERF_CNT+65):  begin s_slave_r_rdata       = perf_cnt_L2[7][0]; end
          (BASE_PERF_CNT+66):  begin s_slave_r_rdata       = perf_cnt_L2[7][1]; end
          (BASE_PERF_CNT+67):  begin s_slave_r_rdata       = perf_cnt_L2[7][2]; end


          default : begin s_slave_r_rdata = 32'hDEAD_CA5E; end
          endcase

     end

   always_ff @(posedge clk_i, negedge rst_ni)
   begin : SEQ_PROC
      if(rst_ni == 1'b0)
      begin
              CS                       <= IDLE;

              L1_mask_bypass_req_CS    <= '0;
              L1_mask_flush_req_CS     <= '0;
              L1_mask_sel_flush_req_CS <= '0;

              L2_mask_enable_req_CS    <= '0;
              L2_mask_disable_req_CS   <= '0;
              L2_mask_flush_req_CS     <= '0;
              L2_mask_sel_flush_req_CS <= '0;

              speriph_slave_r_id_o    <=   '0;
              speriph_slave_r_valid_o <= 1'b0;
              speriph_slave_r_rdata_o <=   '0;
              speriph_slave_r_opc_o   <= 1'b0;

              r_enable_icache    <=   '0;
              r_flush_icache     <=   '0;
              r_sel_flush_icache <=   '0;

              r_clear_cnt        <=   '0;
              r_enable_cnt       <=   '0;
              enable_l1_l15_prefetch_o  <=  'h00;
      end
      else
      begin

        CS                       <= NS;

        L1_mask_bypass_req_CS    <= L1_mask_bypass_req_NS;
        L1_mask_flush_req_CS     <= L1_mask_flush_req_NS;
        L1_mask_sel_flush_req_CS <= L1_mask_sel_flush_req_NS;

        L2_mask_enable_req_CS    <= L2_mask_enable_req_NS;
        L2_mask_disable_req_CS   <= L2_mask_disable_req_NS;
        L2_mask_flush_req_CS     <= L2_mask_flush_req_NS;
        L2_mask_sel_flush_req_CS <= L2_mask_sel_flush_req_NS;

        if(is_write)
        begin
            if(speriph_slave_addr_i[9:2] == {2'b0,ENABLE_ICACHE_ADDR})
            // ENABLE-DISABLE
                begin
                  //r_enable_icache[NB_CORES+NB_CACHE_BANKS-1:0] <= {(NB_CORES+NB_CACHE_BANKS){speriph_slave_wdata_i[0]}};
                  r_enable_icache <= speriph_slave_wdata_i[0];
                end
	        else if(speriph_slave_addr_i[9:2] == {2'b0,FLUSH_ICACHE_ADDR})
	        // FLUSH
                begin
                  r_flush_icache[NB_CORES+NB_CACHE_BANKS-1:0] <= {(NB_CORES+NB_CACHE_BANKS){speriph_slave_wdata_i[0]}};
                end

            else if(speriph_slave_addr_i[9:2] == {2'b0,FLUSH_L1_ONLY_ADDR})
	        // FLUSH_L1_ONLY
                begin
                  r_flush_icache[NB_CORES+NB_CACHE_BANKS-1:0] <= {{(NB_CACHE_BANKS){1'b0}}, {(NB_CORES){speriph_slave_wdata_i[0]}} };
                end
            else if(speriph_slave_addr_i[9:2] == {2'b0,SEL_FLUSH_ICACHE_ADDR})
	        // Sel FLUSH
                begin
                  r_sel_flush_icache <= speriph_slave_wdata_i;
                end
            else if(speriph_slave_addr_i[9:2] == {2'b0,CLEAR_CNTS_ADDR})
                // CLEAR
                begin
                  r_clear_cnt[NB_CORES+NB_CACHE_BANKS-1:0] <= {(NB_CORES+NB_CACHE_BANKS){speriph_slave_wdata_i[0]}};
                end

            else if(speriph_slave_addr_i[9:2] == {2'b0,ENABLE_CNTS_ADDR})
	        // ENABLE-DISABLE STAT REGS
                begin
                  //r_enable_cnt[NB_CORES+NB_CACHE_BANKS-1:0] <= {(NB_CORES+NB_CACHE_BANKS){speriph_slave_wdata_i[0]}};
                  r_enable_cnt <= speriph_slave_wdata_i[0];
                end
            //#prefetch uncomment this block
            /*
            else if(speriph_slave_addr_i[9:2] == {2'b0,ENABLE_L1_L15_PREFETCH_ADDR})
	        // enable l1 to l15 prefetch feature
                begin
                  enable_l1_l15_prefetch_o <= speriph_slave_wdata_i[NB_CORES-1:0];
                end
            */
        end
        else // Not Write
        begin
            if(clear_flush_reg)
               r_flush_icache[NB_CORES+NB_CACHE_BANKS-1:0] <= { (NB_CORES+NB_CACHE_BANKS){1'b0} };
        end


        // sample the ID
        if(speriph_slave_req_i & speriph_slave_gnt_o)
        begin
          speriph_slave_r_id_o  <= speriph_slave_id_i;
        end


        //Handle register read
        if(deliver_response == 1'b1)
        begin
          speriph_slave_r_valid_o <= 1'b1;

          if(is_write_response) begin
              speriph_slave_r_opc_o <= is_write_error;
              if(is_write_error) begin
                  speriph_slave_r_rdata_o <= 32'hBAD_ACCE5;
              end else begin
                  speriph_slave_r_rdata_o <= '0;
              end
          end else begin
              speriph_slave_r_opc_o <= is_read_error;
              if(is_read_error) begin
                  speriph_slave_r_rdata_o <= 32'hBAD_ACCE5;
              end else begin
                  speriph_slave_r_rdata_o <= s_slave_r_rdata;
              end
          end
        end
        else //nothing to Do
        begin
            speriph_slave_r_valid_o <= 1'b0;
            speriph_slave_r_opc_o   <= 1'b0;
            speriph_slave_r_rdata_o <= '0;
        end
      end
  end

endgenerate







   always_comb
   begin : p_icache
        // SPER SIDE
        speriph_slave_gnt_o    = 1'b0;

        is_write               = 1'b0;
        is_write_response      = 1'b0;
        deliver_response       = 1'b0;

        L1_icache_sel_flush_req_o = '0;
        L2_icache_sel_flush_req_o = '0;

        clear_flush_reg           = 1'b0;

        L1_mask_bypass_req_NS     = L1_mask_bypass_req_CS;
        L1_mask_flush_req_NS      = L1_mask_flush_req_CS;
        L1_mask_sel_flush_req_NS  = L1_mask_sel_flush_req_CS;

        L2_mask_sel_flush_req_NS  = L2_mask_sel_flush_req_CS;
        L2_mask_enable_req_NS     = L2_mask_enable_req_CS;
        L2_mask_disable_req_NS    = L2_mask_disable_req_CS;
        L2_mask_flush_req_NS      = L2_mask_flush_req_CS;

        L2_icache_flush_req_o     =   '0;
        L1_icache_flush_req_o     =   '0;

        L1_icache_sel_flush_req_o = '0;
        L2_icache_sel_flush_req_o = '0;

        L1_clear_regs_o          = '0;
        L2_clear_regs_o          = '0;

        is_write_error           = 1'b0;
        is_read_error            = 1'b0;

        NS = CS;

        case(CS)

          IDLE:
          begin
              speriph_slave_gnt_o = 1'b1;

              if(speriph_slave_req_i)
              begin
                if(speriph_slave_we_n_i == 1'b1) // read
                begin
                      NS               = IDLE;
                      deliver_response = 1'b1;
                      if(speriph_slave_addr_i[8:2] == 7'h02) begin
                        is_read_error = 1'b1;
                      end
                      if(speriph_slave_addr_i[8:2] == 7'h04) begin
                        is_read_error = 1'b1;
                      end
                      if(speriph_slave_addr_i[8:2] == 7'h06) begin
                        is_read_error = 1'b1;
                      end
                      //#prefetch remove read error for 7
                      if(speriph_slave_addr_i[8:2] == 7'h07) begin
                        is_read_error = 1'b1;
                      end
                      if(speriph_slave_addr_i[8:2] == 7'h08) begin
                        is_read_error = 1'b1;
                      end
                      if(speriph_slave_addr_i[8:2] == 7'h09) begin
                        is_read_error = 1'b1;
                      end
                      if(speriph_slave_addr_i[8:2] == 7'h0A) begin
                        is_read_error = 1'b1;
                      end
                      if(speriph_slave_addr_i[8:2] == 7'h0B) begin
                        is_read_error = 1'b1;
                      end
                      if(speriph_slave_addr_i[8:2] == 7'h13) begin
                        is_read_error = 1'b1;
                      end
                      if(speriph_slave_addr_i[9:0] >= 10'h100) begin // speriph_slave_addr_i[7:2] > ENABLE_L1_L15_PREFETCH_ADDR
                        is_read_error = 1'b1;
                      end
                      if(NB_CORES == 4) begin
                          if(speriph_slave_addr_i[8:2]>=7'h24 && speriph_slave_addr_i[8:2]< 7'h34 ) begin
                              is_read_error = 1'b1;
                          end
                      end
                      if(NB_CACHE_BANKS == 2) begin
                          if(speriph_slave_addr_i[8:2] >= 7'h3A) begin //
                              is_read_error = 1'b1;
                          end
                      end
                      if(NB_CACHE_BANKS == 4) begin
                          if(speriph_slave_addr_i[8:2] >= 7'h40) begin //
                              is_read_error = 1'b1;
                          end
                      end
                end
                else // Write registers
                begin

                      is_write = 1'b1;
                      is_write_response = 1'b1;
                      NS = IDLE;

                      case(speriph_slave_addr_i[9:2])
                            {2'b0,ENABLE_ICACHE_ADDR}: // Enable - Disable register
                            begin
                                if( speriph_slave_wdata_i[0] == 1'b0 )
                                begin
                                  NS = DISABLE_ICACHE;
                                  L1_mask_bypass_req_NS  = L1_icache_bypass_req_o;
                                  L2_mask_disable_req_NS = L2_icache_disable_req_o;
                                end
                                else
                                begin
                                  NS = ENABLE_ICACHE;
                                  L1_mask_bypass_req_NS =  L1_icache_bypass_req_o;
                                  L2_mask_enable_req_NS =  L2_icache_enable_req_o;
                                end
                            end //~2'b0
                            {2'b0,FLUSH_ICACHE_ADDR}:
                            begin
                              NS = FLUSH_ICACHE_CHECK;
                              L1_mask_flush_req_NS = ~{(NB_CORES){speriph_slave_wdata_i[0]}};
                              L2_mask_flush_req_NS = ~{(NB_CACHE_BANKS){speriph_slave_wdata_i[0]}};
                            end
                            {2'b0,FLUSH_L1_ONLY_ADDR}:
                            begin
                              NS = FLUSH_ICACHE_CHECK;
                              L1_mask_flush_req_NS = ~{(NB_CORES){speriph_slave_wdata_i[0]}};
                              L2_mask_flush_req_NS = '1;
                            end
                            {2'b0,SEL_FLUSH_ICACHE_ADDR}:
                            begin
                              NS = SEL_FLUSH_ICACHE;
                              L1_mask_sel_flush_req_NS = L1_icache_sel_flush_req_o;
                              L2_mask_sel_flush_req_NS = L2_icache_sel_flush_req_o;
                            end
                            {2'b0,CLEAR_CNTS_ADDR}: // CLEAR
                            begin
                              NS = CLEAR_STAT_REGS;
                            end
                            {2'b0,ENABLE_CNTS_ADDR}: // START
                            begin
                              NS = ENABLE_STAT_REGS;
                            end
                            {2'b0,ENABLE_L1_L15_PREFETCH_ADDR}: // Enable L1_L15
                            begin
                              NS = IDLE;
        	                    deliver_response       = 1'b1;
                              is_write_error         = 1'b1; //#prefetch remove this line
                            end
                            default:
                            begin
                              NS = IDLE;
        	                    deliver_response       = 1'b1;
                              is_write_error         = 1'b1;
                            end
                      endcase

                end

              end
              else // no request
              begin
                  NS = IDLE;
              end

          end //~IDLE

          CLEAR_STAT_REGS:
          begin
             for(x=0; x<NB_CORES; x++)
             begin
                L1_clear_regs_o[x]  =   r_clear_cnt[x];
             end

             for(x=0; x<NB_CACHE_BANKS; x++)
             begin
                L2_clear_regs_o[x]  =   r_clear_cnt[x+NB_CORES];
             end


             deliver_response = 1'b1;
             is_write_response = 1'b1;
             NS = IDLE;
          end //~ CLEAR_STAT_REGS


          ENABLE_STAT_REGS:
          begin

             deliver_response = 1'b1;
             is_write_response = 1'b1;
             NS = IDLE;
          end //~ENABLE_STAT_REGS





          ENABLE_ICACHE:
          begin
            speriph_slave_gnt_o = 1'b0;
            L1_mask_bypass_req_NS = L1_icache_bypass_ack_i & L1_mask_bypass_req_CS;
            L2_mask_enable_req_NS = L2_icache_enable_ack_i | L2_mask_enable_req_CS;



            if( ((L1_icache_bypass_ack_i | L1_mask_bypass_req_CS) == '0 )  &&  ((L2_icache_enable_ack_i | L2_mask_enable_req_CS) == '1)  ) //11111 --> all enabled; 00000 --> all enabled
            begin
              NS = IDLE;
              deliver_response = 1'b1;
              is_write_response = 1'b1;
            end
            else
            begin
              NS = ENABLE_ICACHE;
            end
          end //~ENABLE_ICACHE






          DISABLE_ICACHE:
          begin
            speriph_slave_gnt_o = 1'b0;

            L1_mask_bypass_req_NS  = L1_icache_bypass_ack_i  | L1_mask_bypass_req_CS;
            L2_mask_disable_req_NS = L2_icache_disable_ack_i | L2_mask_disable_req_CS;

            //if(  &({L2_icache_disable_ack_i,L1_icache_bypass_ack_i} | {L2_mask_disable_req_CS, L1_mask_bypass_req_CS}  ) ) //11111 --> all bypassed; 00000 --> all enabled
            if(  (&(L2_icache_disable_ack_i | L2_mask_disable_req_CS))  &&     (&(L1_mask_bypass_req_CS | L1_icache_bypass_ack_i ))  )
            begin
              NS = IDLE;
              deliver_response = 1'b1;
              is_write_response = 1'b1;
            end
            else
            begin
              NS = DISABLE_ICACHE;
            end
          end //~DIABLE_ICACHE


          FLUSH_ICACHE_CHECK:
          begin
              speriph_slave_gnt_o = 1'b0;
              L1_mask_flush_req_NS = L1_icache_flush_ack_i | L1_mask_flush_req_CS;
              L2_mask_flush_req_NS = L2_icache_flush_ack_i | L2_mask_flush_req_CS;
              L2_icache_flush_req_o     =  r_flush_icache[NB_CACHE_BANKS+NB_CORES-1:NB_CORES] & (~L2_mask_flush_req_CS);
              L1_icache_flush_req_o     =  r_flush_icache[NB_CORES-1:0] & (~L1_mask_flush_req_CS);

              if(  &{ L2_mask_flush_req_CS , L1_mask_flush_req_CS } )
              begin
                 NS = IDLE;
                 deliver_response = 1'b1;
                 is_write_response = 1'b1;
                 clear_flush_reg  = 1'b1;
              end
              else
              begin
                NS = FLUSH_ICACHE_CHECK;
              end
          end


          SEL_FLUSH_ICACHE:
          begin
              speriph_slave_gnt_o = 1'b0;
              L2_mask_sel_flush_req_NS = L2_mask_sel_flush_req_CS | L2_icache_sel_flush_ack_i;
              L1_mask_sel_flush_req_NS = L1_mask_sel_flush_req_CS | L1_icache_sel_flush_ack_i;
              L1_icache_sel_flush_req_o = ~L1_mask_sel_flush_req_CS;
              L2_icache_sel_flush_req_o = ~L2_mask_sel_flush_req_CS;

              if( &{ L2_mask_sel_flush_req_CS, L1_mask_sel_flush_req_CS } )
              begin
                // speriph_slave_gnt_o = 1'b1;
                NS  = IDLE;
                deliver_response = 1'b1;
                is_write_response = 1'b1;
              end
              else
              begin
                NS = SEL_FLUSH_ICACHE;
              end
          end


        default :
        begin
                NS = IDLE;
        end
        endcase
   end


endmodule
