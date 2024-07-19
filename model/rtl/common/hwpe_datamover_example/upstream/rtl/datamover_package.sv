/*
 * datamover_package.sv
 * Francesco Conti <f.conti@unibo.it>
 *
 * Copyright (C) 2019-2020 ETH Zurich, University of Bologna
 * Copyright and related rights are licensed under the Solderpad Hardware
 * License, Version 0.51 (the "License"); you may not use this file except in
 * compliance with the License.  You may obtain a copy of the License at
 * http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
 * or agreed to in writing, software, hardware and materials distributed under
 * this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
 * CONDITIONS OF ANY KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations under the License.
 */

package datamover_package;

  typedef struct packed {
    hci_package::hci_streamer_ctrl_t data_in_source_ctrl;
    hci_package::hci_streamer_ctrl_t data_out_sink_ctrl;
  } ctrl_streamer_t;
  typedef struct packed {
    hci_package::hci_streamer_flags_t data_in_source_flags;
    hci_package::hci_streamer_flags_t data_out_sink_flags;
    logic tcdm_fifo_empty;
  } flags_streamer_t;

endpackage
