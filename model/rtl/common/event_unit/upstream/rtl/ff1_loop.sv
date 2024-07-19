// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

module ff1_loop
#(
  parameter int WIDTH = 4
)
(
  input  logic [WIDTH-1:0]         vector_i,
  output logic [$clog2(WIDTH)-1:0] idx_bin_o,
  output logic                     no1_o
);

  assign no1_o = ~(|vector_i);

  logic found;

  always_comb begin
    found     = 1'b0;
    idx_bin_o = '0;

    for (int i = 0; i < WIDTH; i++) begin
      if ( (vector_i[i] == 1'b1) && (found == 1'b0) ) begin
        found     = 1'b1;
        idx_bin_o = i;
      end
    end
  end

endmodule
