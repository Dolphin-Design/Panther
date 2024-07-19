/*
 * Copyright (C) 2020 ETH Zurich and University of Bologna
 *
 * Copyright and related rights are licensed under the Solderpad Hardware
 * License, Version 0.51 (the "License"); you may not use this file except in
 * compliance with the License.  You may obtain a copy of the License at
 * http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
 * or agreed to in writing, software, hardware and materials distributed under
 * this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
 * CONDITIONS OF ANY KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations under the License.
 */

/*
 * Authors:  Francesco Conti <f.conti@unibo.it>
 */

import hwpe_stream_package::*;
import hci_package::*;

module datamover_engine #(
  parameter int unsigned FIFO_DEPTH = 4,
  parameter int unsigned BW_ALIGNED = 32
) (
  // global signals
  input  logic                   clk_i,
  input  logic                   rst_ni,
  input  logic                   test_mode_i,
  // local enable & clear
  input  logic                   enable_i,
  input  logic                   clear_i,
  // input data stream + handshake
  hwpe_stream_intf_stream.sink   data_in,
  // output data stream + handshake
  hwpe_stream_intf_stream.source data_out
);

  // for this example, the datapath is simply a data FIFO!

  hwpe_stream_fifo #(
    .DATA_WIDTH ( BW_ALIGNED ),
    .FIFO_DEPTH ( FIFO_DEPTH )
  ) i_fifo (
    .clk_i   ( clk_i    ),
    .rst_ni  ( rst_ni   ),
    .clear_i ( clear_i  ),
    .flags_o (          ),
    .push_i  ( data_in  ),
    .pop_o   ( data_out )
  );

endmodule // datamover_streamer
