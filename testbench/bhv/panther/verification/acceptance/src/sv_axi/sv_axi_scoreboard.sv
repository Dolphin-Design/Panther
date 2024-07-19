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

class sv_axi_scoreboard #(parameter int AXI_ADDR_WIDTH = 32, parameter int AXI_DATA_WIDTH = 64, parameter int AXI_ID_WIDTH = 4, parameter int AXI_USER_WIDTH = 6);

    typedef sv_axi_trans #(
        AXI_ADDR_WIDTH,
        AXI_DATA_WIDTH,
        AXI_ID_WIDTH  ,
        AXI_USER_WIDTH
    ) sv_axi_trans_t;

    mailbox mb_m2s;
    int rx_nb;
    int id;
    sv_axi_trans_t ref_transactions [$];
    sv_axi_trans_t got_transactions [$];
    event scb_ended;


    function new(mailbox mb_m2s, event scb_ended, int id = -1);
        this.mb_m2s    = mb_m2s;
        this.scb_ended = scb_ended;
        this.id        = id;
        this.rx_nb     = 0;
    endfunction


    task reset();
        rx_nb = 0;
        ref_transactions.delete();
        got_transactions.delete();
    endtask


    task print_tr(sv_axi_trans_t i_tr, string i_text);
        $display($sformatf("%s", i_text));
        if (i_tr.w_en) begin
            $display($sformatf("\t- waddress : %08x", i_tr.waddress));
            for (int i = 0; i <= i_tr.wlen; i++)
                $display($sformatf("\t- wdata[%2d]: %08x", i, i_tr.wdata[i]));
        end
        else begin
            $display($sformatf("\t- raddress : %08x", i_tr.raddress));
            for (int i = 0; i <= i_tr.rlen; i++)
                $display($sformatf("\t- rdata[%2d]: %08x", i, i_tr.rdata[i]));
        end
    endtask


    task main();
        sv_axi_trans_t axi_rx;

        forever begin
            mb_m2s.get(axi_rx);
            got_transactions.push_back(axi_rx);
            rx_nb++;
        end
    endtask


    function int compare_transactions (sv_axi_trans_t trA, sv_axi_trans_t trB) ;
        int ok = 0;

        if (trA.w_en != trB.w_en) 
            return 1;

        if (trA.r_en != trB.r_en) 
            return 1;

        if (trA.w_en) begin
            if (trA.waddress != trB.waddress) 
                return 1;

            if (trA.wlen != trB.wlen) 
                return 1;

            for (int i = 0; i <= trA.wlen; i++) begin
                if (trA.wdata[i] != trB.wdata[i]) 
                    return 1;
            end
        end 
        else begin
            if (trA.raddress != trB.raddress) 
                return 1;

            if (trA.rlen != trB.rlen) 
                return 1;

            for (int i = 0; i <= trA.rlen; i++) begin
                if (trA.rdata[i] != trB.rdata[i]) 
                    return 1;
            end
        end

        return 0;
    endfunction


    task compare_transactions_with_file(string i_filename);
        sv_axi_trans_t axi_rx_ref;
        sv_axi_trans_t axi_ref_tr;
        sv_axi_trans_t axi_got_tr;
        int r;
        logic [AXI_DATA_WIDTH-1:0] tmp_data;
        logic [AXI_ADDR_WIDTH-1:0] tmp_addr;
        int                        tmp_len;
        int                        ignore_cmd;
        string                     command, tmp_str;
        
        int nb_lines_read =0;
        int burst_cnt = 0;
        int tr_idx = 0;
        int fd = $fopen(i_filename, "r");

        if (fd == 0) begin
            $warning("** Warning : [AXI_SCB_%0d] No AXI transaction will be checked by this scoreboard\n", id);
        end 
        else begin

            while (!$feof(fd)) begin
                command = "invalid";
                axi_rx_ref = new();
                ignore_cmd = 0;

                r = $fgets(tmp_str, fd);
                nb_lines_read++;

                r = (r <= 1) ? 0 : $sscanf (tmp_str, "%s", command);

                case (command)
                    "read": begin
                        r = $sscanf (tmp_str, "%s %x %x %x", command, tmp_len, tmp_addr, tmp_data);
                        if (r != 4) 
                            ignore_cmd = 1;

                        axi_rx_ref.wdata = new[1];
                        axi_rx_ref.rdata = new[tmp_len+1];

                        axi_rx_ref.w_en     = 0;
                        axi_rx_ref.r_en     = 1;
                        axi_rx_ref.raddress = tmp_addr;
                        axi_rx_ref.rlen     = tmp_len;
                        axi_rx_ref.rdata[0] = tmp_data;
                        
                        //read next rdata beats
                        burst_cnt = 0;
                        while ((burst_cnt < tmp_len) && !$feof(fd)) begin
                            r = $fgets(tmp_str, fd);
                            nb_lines_read++;

                            r = $sscanf (tmp_str, "%s %x", command, tmp_data);
                            if ((r != 2) || (command != "beat")) begin
                                $display("** Warning : [AXI_SCB_%0d] Command %s on line %0d is not valid", id, command, nb_lines_read);
                            end
                            else begin
                                burst_cnt++;
                                axi_rx_ref.rdata[burst_cnt] = tmp_data;
                            end
                        end
                    end
                    "write": begin
                        r = $sscanf (tmp_str, "%s %x %x %x", command, tmp_len, tmp_addr, tmp_data);
                        if (r != 4) 
                            ignore_cmd = 1;

                        axi_rx_ref.wdata = new[tmp_len+1];
                        axi_rx_ref.rdata = new[1];

                        axi_rx_ref.r_en     = 0;
                        axi_rx_ref.w_en     = 1;
                        axi_rx_ref.waddress = tmp_addr;
                        axi_rx_ref.wlen     = tmp_len;
                        axi_rx_ref.wdata[0] = tmp_data;

                        //read next wdata beats
                        burst_cnt = 0;
                        while ((burst_cnt < tmp_len) && !$feof(fd)) begin
                            r = $fgets(tmp_str, fd);
                            nb_lines_read++;

                            r = $sscanf (tmp_str, "%s %x", command, tmp_data);
                            if ((r != 2) || (command != "beat")) begin
                                $display("** Warning : [AXI_SCB_%0d] Command %s on line %0d is not valid", id, command, nb_lines_read);
                            end
                            else begin
                                burst_cnt++;
                                axi_rx_ref.wdata[burst_cnt] = tmp_data;
                            end
                        end
                    end
                    default: ignore_cmd = 1;
                endcase

                if (!ignore_cmd) begin
                    ref_transactions.push_back(axi_rx_ref);
                    tr_idx ++;
                end
            end

            if (ref_transactions.size() != got_transactions.size()) begin
                $display("** Error: [AXI_SCB_%0d] number of transactions expected by the scoreboard doesn't match the number of transaction got. %0d vs %0d", id, ref_transactions.size(), got_transactions.size());
            end

            if (ref_transactions.size() == 0) begin
                $display("** Warning: [AXI_SCB_%0d] No transactions for this scoreboard", id);
            end

            while (got_transactions.size() && ref_transactions.size()) begin
                axi_ref_tr = ref_transactions.pop_front();
                axi_got_tr = got_transactions.pop_front();
                if (compare_transactions(axi_ref_tr, axi_got_tr)) begin
                    $display("** Error : [AXI_SCB_%0d] Transaction received don't match", id);
                    print_tr(axi_ref_tr, "axi_ref_tr : ");
                    print_tr(axi_got_tr, "axi_got_tr : ");
                end
            end

            $display("[AXI_SCB_%0d] All transactions processed", id);
            ->scb_ended;
        end
    endtask

endclass
