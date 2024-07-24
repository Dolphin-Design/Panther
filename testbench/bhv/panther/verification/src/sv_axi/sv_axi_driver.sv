// Copyright 2024 Dolphin Design
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Licensed under the Solderpad Hardware License v 2.1 (the "License");
// you may not use this file except in compliance with the License, or,
// at your option, the Apache License version 2.0.
// You may obtain a copy of the License at
//
// https://solderpad.org/licenses/SHL-2.1/
//
// Unless required by applicable law or agreed to in writing, any work
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

class sv_axi_driver #(parameter int AXI_ADDR_WIDTH = 32, parameter int AXI_DATA_WIDTH = 64, parameter int AXI_ID_WIDTH = 4, parameter int AXI_USER_WIDTH = 6);

    typedef sv_axi_trans #(
        AXI_ADDR_WIDTH,
        AXI_DATA_WIDTH,
        AXI_ID_WIDTH  ,
        AXI_USER_WIDTH
    ) sv_axi_trans_t;

    virtual sv_axi_interface #(
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .AXI_ID_WIDTH  (AXI_ID_WIDTH  ),
        .AXI_USER_WIDTH(AXI_USER_WIDTH)
    ) axi_vif;

    mailbox mb_g2d;
    int tx_nb = 0;
    int id;

    function new(virtual sv_axi_interface #(AXI_ADDR_WIDTH, AXI_DATA_WIDTH, AXI_ID_WIDTH, AXI_USER_WIDTH) axi_vif, mailbox mb_g2d, int id = -1);
        this.axi_vif = axi_vif;
        this.mb_g2d  = mb_g2d;
        this.id      = id;
    endfunction


    task print_tr(sv_axi_trans_t i_tr, string i_text);
        $display($sformatf("%s", i_text));
        $display($sformatf("\t- waddress : %08x", i_tr.waddress));
        for (int i = 0; i < i_tr.wlen; i++)
            $display($sformatf("\t- wdata[%2d]: %08x", i, i_tr.wdata[i]));
        $display($sformatf("\t- waddress : %08x", i_tr.raddress));
        for (int i = 0; i < i_tr.rlen; i++)
            $display($sformatf("\t- rdata[%2d]: %08x", i, i_tr.rdata[i]));
    endtask

    task reset;
        tx_nb   = 0;
        forever begin
            wait(axi_vif.aresetn == 0);
            axi_vif.awvalid    <= '0;
            axi_vif.awaddr     <= '0;
            axi_vif.awsize     <= '0;
            axi_vif.awburst    <= '0;
            axi_vif.awcache    <= '0;
            axi_vif.awprot     <= '0;
            axi_vif.awid       <= '0;
            axi_vif.awlen      <= '0;
            axi_vif.awlock     <= '0;
            axi_vif.awqos      <= '0;
            axi_vif.awregion   <= '0;
            axi_vif.awuser     <= '0;
            axi_vif.wvalid     <= '0;
            axi_vif.wlast      <= '0;
            axi_vif.wdata      <= '0;
            axi_vif.wstrb      <= '0;
            axi_vif.wuser      <= '0;
            axi_vif.bready     <= '0;
            axi_vif.arvalid    <= '0;
            axi_vif.araddr     <= '0;
            axi_vif.arsize     <= '0;
            axi_vif.arburst    <= '0;
            axi_vif.arcache    <= '0;
            axi_vif.arprot     <= '0;
            axi_vif.arid       <= '0;
            axi_vif.arlen      <= '0;
            axi_vif.arlock     <= '0;
            axi_vif.arqos      <= '0;
            axi_vif.arregion   <= '0;
            axi_vif.aruser     <= '0;
            axi_vif.rready     <= '0;
            wait(axi_vif.aresetn == 1);
        end
    endtask

    task drive;
        sv_axi_trans_t tx;
        forever begin

            @(axi_vif.driver_cb iff (axi_vif.driver_cb.aresetn));
            mb_g2d.get(tx);

            if (tx.wait_eoc) begin
                wait (axi_vif.eoc);
                $display("End of conversion done [%f]", $time);
            end 
            else begin

                if (tx.w_en) begin 

                    @(axi_vif.driver_cb);
                    
                    // set Write Address Channel 
                    axi_vif.driver_cb.awvalid   <= 1'b1;
                    axi_vif.driver_cb.awaddr    <= tx.waddress;
                    axi_vif.driver_cb.awsize    <= 3'b011; // 8 bytes
                    axi_vif.driver_cb.awlen     <= tx.wlen;
                    axi_vif.driver_cb.awburst   <= 1;

                    @(axi_vif.driver_cb iff (axi_vif.driver_cb.awready));

                    // clear Write Address Channel
                    axi_vif.driver_cb.awvalid   <= 1'b0;
                    axi_vif.driver_cb.awaddr    <= '0;
                    axi_vif.driver_cb.awsize    <= '0;
                    axi_vif.driver_cb.awlen     <= '0;
                    axi_vif.driver_cb.awburst   <= '0;
                    
                    //drive the first n-1 bursts
                    for (int i = 0; i < tx.wlen; i++) begin
                        @(axi_vif.driver_cb);

                        // set Write Channel 
                        axi_vif.driver_cb.wvalid  <= 1'b1;
                        axi_vif.driver_cb.wdata   <= tx.wdata[i];
                        axi_vif.driver_cb.wstrb   <= {(AXI_DATA_WIDTH/8){1'b1}};
                        axi_vif.driver_cb.wlast   <= '0;
                        axi_vif.driver_cb.wuser   <= '0;

                        @(axi_vif.driver_cb iff (axi_vif.driver_cb.wready));

                        // clear Write Channel
                        axi_vif.driver_cb.wvalid  <= 1'b0;
                        axi_vif.driver_cb.wdata   <= '0;
                        axi_vif.driver_cb.wstrb   <= '0;
                    end 

                    //drive the last burst
                    @(axi_vif.driver_cb);
                    
                    // set Write Channel 
                    axi_vif.driver_cb.wvalid  <= 1'b1;
                    axi_vif.driver_cb.wdata   <= tx.wdata[tx.wlen];
                    axi_vif.driver_cb.wstrb   <= {(AXI_DATA_WIDTH/8){1'b1}};
                    axi_vif.driver_cb.wlast   <= '1;
                    axi_vif.driver_cb.wuser   <= '0;

                    @(axi_vif.driver_cb iff (axi_vif.driver_cb.wready));

                    // clear Write Channel
                    axi_vif.driver_cb.wvalid  <= 1'b0;
                    axi_vif.driver_cb.wdata   <= '0;
                    axi_vif.driver_cb.wstrb   <= '0;
                    axi_vif.driver_cb.wlast   <= '0;

                    @(axi_vif.driver_cb);

                    // set Write Response Channel 
                    axi_vif.driver_cb.bready <= 1'b1;

                    @(axi_vif.driver_cb iff (axi_vif.driver_cb.bvalid));

                    // clear Write Response Channel
                    axi_vif.driver_cb.bready <= 1'b0;
                    tx_nb ++;
                end 

                else begin
                    @(axi_vif.driver_cb);

                    // set Read Address Channel 
                    axi_vif.driver_cb.arvalid   <= 1'b1;
                    axi_vif.driver_cb.araddr    <= tx.raddress;
                    axi_vif.driver_cb.arsize    <= 3'b011;  // 8 bytes
                    axi_vif.driver_cb.arlen     <= tx.rlen;
                    axi_vif.driver_cb.arburst   <= 1;

                    @(axi_vif.driver_cb iff (axi_vif.driver_cb.arready));

                    // clear Read Address Channel
                    axi_vif.driver_cb.arvalid <= 1'b0;
                    axi_vif.driver_cb.araddr  <= '0;
                    axi_vif.driver_cb.arsize  <= '0;
                    axi_vif.driver_cb.arlen   <= '0;
                    axi_vif.driver_cb.arburst <= '0;

                    // Read Channel
                    for (int i = 0; i <= tx.rlen; i++) begin
                        @(axi_vif.driver_cb);

                        axi_vif.driver_cb.rready <= 1'b1;

                        @(axi_vif.driver_cb iff (axi_vif.driver_cb.rvalid));

                        // clear Read Channel
                        axi_vif.driver_cb.rready <= 1'b0;
                    end
                    tx_nb ++;
                end
            end
        end
    endtask

endclass
