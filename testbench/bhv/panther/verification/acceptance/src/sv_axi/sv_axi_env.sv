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

class sv_axi_env #(int AXI_ADDR_WIDTH = 32, int AXI_DATA_WIDTH = 64, int AXI_ID_WIDTH = 4, int AXI_USER_WIDTH = 6 );

    sv_axi_gen        #(AXI_ADDR_WIDTH, AXI_DATA_WIDTH, AXI_ID_WIDTH, AXI_USER_WIDTH) axi_gen;
    sv_axi_driver     #(AXI_ADDR_WIDTH, AXI_DATA_WIDTH, AXI_ID_WIDTH, AXI_USER_WIDTH) axi_driver;
    sv_axi_scoreboard #(AXI_ADDR_WIDTH, AXI_DATA_WIDTH, AXI_ID_WIDTH, AXI_USER_WIDTH) axi_scb;
    sv_axi_monitor    #(AXI_ADDR_WIDTH, AXI_DATA_WIDTH, AXI_ID_WIDTH, AXI_USER_WIDTH) axi_mon;

    mailbox mb_gen2driver;
    mailbox mb_mon2scb;

    event gen_ended;
    event scb_ended;

    int id;

    virtual sv_axi_interface #(
        .AXI_ADDR_WIDTH (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH (AXI_DATA_WIDTH),
        .AXI_ID_WIDTH   (AXI_ID_WIDTH  ),
        .AXI_USER_WIDTH (AXI_USER_WIDTH)
    ) axi_vif;


    function new(virtual sv_axi_interface #(AXI_ADDR_WIDTH, AXI_DATA_WIDTH, AXI_ID_WIDTH, AXI_USER_WIDTH) axi_if, int id = -1);
        this.axi_vif  = axi_if;
        this.id       = id;
        mb_gen2driver = new();
        mb_mon2scb    = new();
        axi_gen       = new(mb_gen2driver, gen_ended, id);
        axi_driver    = new(axi_if, mb_gen2driver, id);
        axi_mon       = new(axi_if, mb_mon2scb, id);
        axi_scb       = new(mb_mon2scb, scb_ended, id);
    endfunction


    task pre_test();
        fork
            axi_driver.reset();
            axi_mon.reset();
            axi_scb.reset();
        join_none;
    endtask


    task test();
        fork
            axi_driver.drive();
            axi_mon.main();
            axi_scb.main();
        join_none;
    endtask


    task post_test();
        wait(gen_ended.triggered); // wait for generator to generate all transactions
        fork
            begin
                wait(axi_driver.tx_nb == axi_gen.nb_tr_sent); // wait for drivers to send all transactions
            end
            begin
                wait(axi_mon.rx_nb    >= axi_gen.nb_tr_sent); // wait for drivers to send all transactions
            end
            begin
                wait(axi_scb.rx_nb    >= axi_gen.nb_tr_sent); // wait for drivers to send all transactions
            end
        join
    endtask


    task run();
        pre_test();
        test();
        fork
            begin
                post_test();
                $display("[AXI_ENV_%0d] ENDED", this.id);
            end
            begin
                #40ms;
                $display("** Error : [AXI_ENV_%0d] Timed-out after 40ms", this.id);
            end
        join_any;
        disable fork;
    endtask

endclass
