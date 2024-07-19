// Copyright 2014-2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License. You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

// Davide Rossi <davide.rossi@unibo.it>

module timer_unit_counter
  (
   input               clk_i,
   input               rst_ni,

   input               write_counter_i,
   input        [31:0] counter_value_i,

   input               reset_count_i,
   input               enable_count_i,
   input        [31:0] compare_value_i,

   output logic [31:0] counter_value_o,
   output logic        target_reached_o
   );

   logic [31:0]        s_count, s_count_reg;
   logic               s_count_ok;
   logic               s_lock_set;
   logic               s_lock_clr;
   logic               r_lock;

   // COUNTER
   always_comb
   begin
      s_count = s_count_reg;

      // start counting
      if ( reset_count_i == 1 )
         s_count = 0;
      else
      begin
         if (write_counter_i == 1) // OVERWRITE COUNTER
           s_count = counter_value_i;
         else
           begin
        if ( enable_count_i == 1 ) // the counter is increased if counter is enabled and there is a tick
          s_count = s_count_reg + 1;
           end
      end
   end

   assign s_count_ok = ( s_count == compare_value_i );

   always_ff@(posedge clk_i, negedge rst_ni)
   begin
      if (rst_ni == 0)
         s_count_reg <= 0;
      else begin
         if ( !(r_lock)  | reset_count_i | write_counter_i)
            s_count_reg <= s_count;
      end
   end

   // lock register to avoid
   assign s_lock_set = enable_count_i & s_count_ok & ~r_lock;
   assign s_lock_clr = (enable_count_i & r_lock) | reset_count_i | write_counter_i;

   always_ff@(posedge clk_i, negedge rst_ni)
   begin
      if (rst_ni == 0)
         r_lock <= 'b0;
      else begin
         if (s_lock_clr)
            r_lock <= '0;
         else if (s_lock_set)
            r_lock <= '1;
      end
   end

   // COMPARATOR
   always_ff@(posedge clk_i, negedge rst_ni)
   begin
      if (rst_ni == 0)
         target_reached_o <= 1'b0;
      else
         if ( s_lock_set )
            target_reached_o <= enable_count_i;
         else
            target_reached_o <= 1'b0;
   end

   assign counter_value_o = s_count_reg;

endmodule
