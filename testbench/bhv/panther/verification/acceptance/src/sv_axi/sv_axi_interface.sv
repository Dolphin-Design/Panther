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

`ifndef SV_AXI_INTERFACE
`define SV_AXI_INTERFACE


interface sv_axi_interface #(
    parameter int AXI_ADDR_WIDTH = 32 ,
    parameter int AXI_DATA_WIDTH = 64 ,
    parameter int AXI_ID_WIDTH   = 4  ,
    parameter int AXI_USER_WIDTH = 6
) (
    input logic aclk, 
    input logic aresetn
);

    logic                           awvalid;
    logic                           awready;
    logic  [AXI_ADDR_WIDTH-1:0]     awaddr;
    logic  [2:0]                    awsize;
    logic  [1:0]                    awburst;
    logic  [3:0]                    awcache;
    logic  [2:0]                    awprot;
    logic  [AXI_ID_WIDTH-1:0]       awid;
    logic  [7:0]                    awlen;
    logic                           awlock;
    logic  [3:0]                    awqos;
    logic  [3:0]                    awregion;
    logic  [AXI_USER_WIDTH-1:0]     awuser;

    logic                           wvalid;
    logic                           wready;
    logic                           wlast;
    logic  [AXI_DATA_WIDTH-1:0]     wdata;
    logic  [(AXI_DATA_WIDTH/8)-1:0] wstrb;
    logic  [AXI_USER_WIDTH-1:0]     wuser;

    logic                           bvalid;
    logic                           bready;
    logic  [1:0]                    bresp;
    logic  [AXI_ID_WIDTH-1:0]       bid;
    logic  [AXI_USER_WIDTH-1:0]     buser;

    logic                           arvalid;
    logic                           arready;
    logic  [AXI_ADDR_WIDTH-1:0]     araddr;
    logic  [2:0]                    arsize;
    logic  [1:0]                    arburst;
    logic  [3:0]                    arcache;
    logic  [2:0]                    arprot;
    logic  [AXI_ID_WIDTH-1:0]       arid;
    logic  [7:0]                    arlen;
    logic                           arlock;
    logic  [3:0]                    arqos;
    logic  [3:0]                    arregion;
    logic  [AXI_USER_WIDTH-1:0]     aruser;

    logic                           rvalid;
    logic                           rready;
    logic                           rlast;
    logic  [AXI_DATA_WIDTH-1:0]     rdata;
    logic  [1:0]                    rresp;
    logic  [AXI_ID_WIDTH-1:0]       rid;
    logic  [AXI_USER_WIDTH-1:0]     ruser;

    logic                           eoc;

    clocking driver_cb @(posedge aclk);
        // default input #1step output #1;
        input   aresetn;
        output  awvalid;
        input   awready;
        output  awaddr;
        output  awsize;
        output  awburst;
        output  awcache;
        output  awprot;
        output  awid;
        output  awlen;
        output  awlock;
        output  awqos;
        output  awregion;
        output  awuser;
        output  wvalid;
        input   wready;
        output  wlast;
        output  wdata;
        output  wstrb;
        output  wuser;
        input   bvalid;
        output  bready;
        input   bresp;
        input   bid;
        input   buser;
        output  arvalid;
        input   arready;
        output  araddr;
        output  arsize;
        output  arburst;
        output  arcache;
        output  arprot;
        output  arid;
        output  arlen;
        output  arlock;
        output  arqos;
        output  arregion;
        output  aruser;
        input   rvalid;
        output  rready;
        input   rlast;
        input   rdata;
        input   rresp;
        input   rid;
        input   ruser;
        input   eoc;
    endclocking

    clocking monitor_cb @(posedge aclk);
        // default input #1step output #1;
        input   aresetn;
        input   awvalid;
        input   awready;
        input   awaddr;
        input   awsize;
        input   awburst;
        input   awcache;
        input   awprot;
        input   awid;
        input   awlen;
        input   awlock;
        input   awqos;
        input   awregion;
        input   awuser;
        input   wvalid;
        input   wready;
        input   wlast;
        input   wdata;
        input   wstrb;
        input   wuser;
        input   bvalid;
        input   bready;
        input   bresp;
        input   bid;
        input   buser;
        input   arvalid;
        input   arready;
        input   araddr;
        input   arsize;
        input   arburst;
        input   arcache;
        input   arprot;
        input   arid;
        input   arlen;
        input   arlock;
        input   arqos;
        input   arregion;
        input   aruser;
        input   rvalid;
        input   rready;
        input   rlast;
        input   rdata;
        input   rresp;
        input   rid;
        input   ruser;
        input   eoc;
    endclocking

endinterface


`endif
