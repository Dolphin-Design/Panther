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

class sv_axi_gen #(parameter int AXI_ADDR_WIDTH = 32, parameter int AXI_DATA_WIDTH = 32, parameter int AXI_ID_WIDTH = 4, parameter int AXI_USER_WIDTH = 6);

    typedef sv_axi_trans #(
        AXI_ADDR_WIDTH,
        AXI_DATA_WIDTH,
        AXI_ID_WIDTH  ,
        AXI_USER_WIDTH
    ) sv_axi_trans_t;

    rand sv_axi_trans_t axi_trans;

    mailbox mb_g2d;
    event gen_ended;

    string input_file;
    integer nb_tr_sent;
    int id;

    function new(mailbox mb_g2d, event gen_ended, int id = -1);
        this.mb_g2d     = mb_g2d;
        this.gen_ended  = gen_ended;
        this.nb_tr_sent = 0;
        this.id         = id;
    endfunction


    task send_random_tr(int i_nb_tr);
        int i = 0;

        repeat(i_nb_tr) begin
            axi_trans = new();
            assert(axi_trans.randomize() );
            $display($sformatf("[AXI_GEN_%0d] Generating transaction number %0d ", id, i));
            print_tr(axi_trans);
            mb_g2d.put(axi_trans);
            i++;
            $display("");
        end
        nb_tr_sent = i_nb_tr;
        -> gen_ended;
    endtask

    task print_tr(sv_axi_trans_t i_tr);
            $display("[AXI_GEN_%0d] Current Transaction:", id);
            $display($sformatf("\t- waddress : %08x", i_tr.waddress));
            for (int i = 0; i < i_tr.wlen; i++)
                $display($sformatf("\t- wdata[%2d]: %08x", i, i_tr.wdata[i]));
            $display($sformatf("\t- raddress : %08x", i_tr.raddress));
            for (int i = 0; i < i_tr.rlen; i++)
                $display($sformatf("\t- rdata[%2d]: %08x", i, i_tr.rdata[i]));
    endtask

    task send_transactions_from_file(input string i_filename);
        sv_axi_trans_t axi_tx;

        int r;

        logic [AXI_DATA_WIDTH-1:0] tmp_data;
        logic [AXI_ADDR_WIDTH-1:0] tmp_addr;
        int                        tmp_len;
        string                     tmp_str;   // used to allow reading of empty lines
        string                     tmp_timeunit;
        integer                    tmp_int;
        string                     command, sub_command; // used to store potential comments on mem files and avoid input file reading failure

        int nb_lines_read;
        int tr_idx     = 0;
        int ignore_cmd = 0;
        int burst_cnt  = 0;
        int fd         = $fopen(i_filename, "r");

        if (fd == 0) begin
            $warning("** Warning : [AXI_GEN_%0d] No AXI transaction will be executed by the AXI64 master\n", id);
        end 
        else begin
            $display($sformatf("Opened %s in read mode", i_filename));
            nb_lines_read = 0;
            while (!$feof(fd)) begin
                command = "invalid";
                ignore_cmd = 0;
                axi_tx = new();

                // fgets + sscanf allow to use comments containing commad keywords at the end + using multiple time string parsing
                r = $fgets(tmp_str, fd);

                r = (r <= 1) ? 0 : $sscanf (tmp_str, "%s", command);
                nb_lines_read++;

                case (command)
                    "read": begin
                        r = $sscanf (tmp_str, "%s %x %x %x", command, tmp_len, tmp_addr, tmp_data);
                        if (r != 4) begin
                            $display("** Warning : [AXI_GEN_%0d] Command %s on line %0d is not valid", id, command, nb_lines_read);
                            ignore_cmd = 1;
                        end 
                        else begin
                            axi_tx.wdata = new[1];
                            axi_tx.rdata = new[tmp_len+1];

                            axi_tx.w_en     = 0;
                            axi_tx.waddress = 0;
                            axi_tx.wdata[0] = 0;
                            axi_tx.wlen     = 0;
                            axi_tx.r_en     = 1;
                            axi_tx.raddress = tmp_addr;
                            axi_tx.rdata[0] = 0; // not used in generator transactions
                            axi_tx.rlen     = tmp_len;

                            //read next rdata beats
                            burst_cnt = 0;
                            while ((burst_cnt < tmp_len) && !$feof(fd)) begin
                                r = $fgets(tmp_str, fd);
                                nb_lines_read++;

                                r = $sscanf (tmp_str, "%s %x", command, tmp_data);
                                if ((r != 2) || (command != "beat")) begin
                                    $display("** Warning : [AXI_GEN_%0d] Command %s on line %0d is not valid", id, command, nb_lines_read);
                                end
                                else begin
                                    burst_cnt++;
                                    axi_tx.rdata[burst_cnt] = 0;
                                end
                            end
                        end
                    end

                    "write": begin
                        r = $sscanf (tmp_str, "%s %x %x %x", command, tmp_len, tmp_addr, tmp_data);
                        if (r != 4) begin
                            $display("** Warning : [AXI_GEN_%0d] Command %s on line %0d is not valid", id, command, nb_lines_read);
                            ignore_cmd = 1;
                        end 
                        else begin
                            axi_tx.wdata = new[tmp_len+1];
                            axi_tx.rdata = new[1];

                            axi_tx.wlen     = tmp_len;
                            axi_tx.rlen     = 0;

                            axi_tx.w_en     = 1;
                            axi_tx.waddress = tmp_addr;
                            axi_tx.wdata[0] = tmp_data;
                            axi_tx.r_en     = 0;
                            axi_tx.raddress = 0;
                            axi_tx.rdata[0] = 0; // not used in generator transactions

                            //read next wdata beats
                            burst_cnt = 0;
                            while ((burst_cnt < tmp_len) && !$feof(fd)) begin
                                r = $fgets(tmp_str, fd);
                                nb_lines_read++;

                                r = $sscanf (tmp_str, "%s %x", command, tmp_data);
                                if ((r != 2) || (command != "beat")) begin
                                    $display("** Warning : [AXI_GEN_%0d] Command %s on line %0d is not valid", id, command, nb_lines_read);
                                end
                                else begin
                                    burst_cnt++;
                                    axi_tx.wdata[burst_cnt] = tmp_data;
                                end
                            end
                        end
                    end

                    "wait": begin
                        ignore_cmd = 1;
                        r = $sscanf (tmp_str, "%s %d%s", command, tmp_int, tmp_timeunit);
                        if (r != 3) begin
                            $display("** Warning : [AXI_GEN_%0d] Command %s on line %0d is not valid", id, command, nb_lines_read);
                        end 
                        else begin
                            case (tmp_timeunit)
                                "fs": repeat(tmp_int) #1fs;
                                "ps": repeat(tmp_int) #1ps;
                                "ns": repeat(tmp_int) #1ns;
                                "us": repeat(tmp_int) #1us;
                                "ms": repeat(tmp_int) #1ms;
                                "s" : repeat(tmp_int) #1s ;
                            endcase
                        end
                    end

                    "beat": begin
                        ignore_cmd = 1;
                        $display("** Warning : [AXI_GEN_%0d] Command %s on line %0d is not valid", id, command, nb_lines_read);
                    end

                    "wait_eoc": begin
                        ignore_cmd = 1;
                        axi_tx.wait_eoc = 1;
                    end

                    default: begin
                        ignore_cmd = 1; // unknown command for driver module
                    end
                endcase

                if (!ignore_cmd) begin
                    mb_g2d.put(axi_tx);
                    tr_idx ++;
                end
                else if (axi_tx.wait_eoc == 1) begin
                    mb_g2d.put(axi_tx);
                end

            end // END WHILE NOT EOF

        end // file given is ok

        nb_tr_sent = tr_idx;
        -> gen_ended;

    endtask

endclass
