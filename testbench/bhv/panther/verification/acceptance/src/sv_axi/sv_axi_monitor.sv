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

class sv_axi_monitor #(parameter int AXI_ADDR_WIDTH = 32, parameter int AXI_DATA_WIDTH = 64, parameter int AXI_ID_WIDTH = 4, parameter int AXI_USER_WIDTH = 6);

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

    mailbox mb_m2s;
    int rx_nb;
    int id;

    function new(virtual sv_axi_interface #(AXI_ADDR_WIDTH, AXI_DATA_WIDTH, AXI_ID_WIDTH, AXI_USER_WIDTH) axi_vif, mailbox mb_m2s, int id = -1);
        this.axi_vif = axi_vif;
        this.mb_m2s  = mb_m2s;
        this.id      = id;
    endfunction

    task reset();
        rx_nb=0;
    endtask

    task print_tr(sv_axi_trans_t i_tr, string i_text);
        $display($sformatf("%s", i_text));
        $display($sformatf("\t- waddress : %08x", i_tr.waddress));
        for (int i = 0; i < i_tr.wlen; i++)
            $display($sformatf("\t- wdata[%2d]: %08x", i, i_tr.wdata[i]));
        $display($sformatf("\t- raddress : %08x", i_tr.raddress));
        for (int i = 0; i < i_tr.rlen; i++)
            $display($sformatf("\t- rdata[%2d]: %08x", i, i_tr.rdata[i]));
    endtask

    task main();
        sv_axi_trans_t axi_rx;

        forever begin
            axi_rx = new();

            @(axi_vif.monitor_cb iff (axi_vif.monitor_cb.awvalid || axi_vif.monitor_cb.arvalid));

            if (axi_vif.monitor_cb.awvalid) begin

                axi_rx.w_en = 1'b1;
                axi_rx.wlen = axi_vif.monitor_cb.awlen;
                axi_rx.wdata = new[axi_rx.wlen+1];

                axi_rx.waddress = axi_vif.monitor_cb.awaddr;
                $display("AXI_MON%0d - WRITE ADDRESS CHANNEL : addr = %0x", id, axi_vif.monitor_cb.awaddr);

                // write address ready
                if (!axi_vif.monitor_cb.awready)
                    @(axi_vif.monitor_cb iff (axi_vif.monitor_cb.awready));

                for (int i = 0; i <= axi_rx.wlen; i++) begin
                    // write valid
                    @(axi_vif.monitor_cb iff (axi_vif.monitor_cb.wvalid && axi_vif.monitor_cb.wready));

                    axi_rx.wdata[i] = axi_vif.monitor_cb.wdata;
                    $display("AXI_MON%0d - WRITE CHANNEL : data[%2d] = %0x", id, i, axi_vif.monitor_cb.wdata);
                end

                // write reponse
                @(axi_vif.monitor_cb iff (axi_vif.monitor_cb.bready && axi_vif.monitor_cb.bvalid));
            end

            else begin // if (axi_vif.monitor_cb.arvalid) begin

                axi_rx.r_en = 1'b1;
                axi_rx.rlen = axi_vif.monitor_cb.arlen;
                axi_rx.rdata = new[axi_rx.rlen+1];

                axi_rx.raddress = axi_vif.monitor_cb.araddr;
                $display("AXI_MON%0d - READ ADDRESS CHANNEL : addr = %0x", id, axi_vif.monitor_cb.araddr);
            
                // read address ready
                if (!axi_vif.monitor_cb.arready)
                     @(axi_vif.monitor_cb iff (axi_vif.monitor_cb.arready));

                for (int i = 0; i <= axi_rx.rlen; i++) begin
                    // read ready
                    @(axi_vif.monitor_cb iff (axi_vif.monitor_cb.rvalid && axi_vif.monitor_cb.rready));

                    axi_rx.rdata[i] = axi_vif.monitor_cb.rdata;
                    $display("AXI_MON%0d - READ CHANNEL : data[%2d] = %0x", id, i, axi_vif.monitor_cb.rdata);
                end
            end

            // register transaction to the scoreboard
            mb_m2s.put(axi_rx);
            rx_nb++;
        end
    endtask

endclass
