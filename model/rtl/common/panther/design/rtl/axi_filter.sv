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

module axi_filter #(
    parameter int                        AXI_ADDR_WIDTH            = 32,
    parameter int                        AXI_DATA_WIDTH            = 64,
    parameter int                        AXI_STRB_WIDTH            = AXI_DATA_WIDTH/8,
    parameter int                        AXI_ID_WIDTH              =  7,
    parameter int                        AXI_USER_WIDTH            =  4,
    parameter int                        NBR_RANGE                 =  1,
    parameter int                        NBR_OUTSTANDING_REQ       =  4,
    parameter int                        AXI_LOOK_BITS             =  4
) (
    input   logic                            i_clk,
    input   logic                            i_rst_n,
    input   logic                            i_scan_ckgt_enable,

    input   logic [AXI_ADDR_WIDTH-1:0]       START_ADDR[NBR_RANGE-1:0],
    input   logic [AXI_ADDR_WIDTH-1:0]       STOP_ADDR [NBR_RANGE-1:0],
    // INPUT
    // WRITE ADDRESS CHANNEL
    input  logic                             axi_in_aw_valid_i ,
    input  logic [AXI_ADDR_WIDTH-1:0]        axi_in_aw_addr_i  ,
    input  logic [2:0]                       axi_in_aw_prot_i  ,
    input  logic [3:0]                       axi_in_aw_region_i,
    input  logic [7:0]                       axi_in_aw_len_i   ,
    input  logic [2:0]                       axi_in_aw_size_i  ,
    input  logic [5:0]                       axi_in_aw_atop_i  ,
    input  logic [1:0]                       axi_in_aw_burst_i ,
    input  logic                             axi_in_aw_lock_i  ,
    input  logic [3:0]                       axi_in_aw_cache_i ,
    input  logic [3:0]                       axi_in_aw_qos_i   ,
    input  logic [AXI_ID_WIDTH-1:0]          axi_in_aw_id_i    ,
    input  logic [AXI_USER_WIDTH-1:0]        axi_in_aw_user_i  ,
    output logic                             axi_in_aw_ready_o ,

    // READ ADDRESS CHANNEL
    input  logic                             axi_in_ar_valid_i ,
    input  logic [AXI_ADDR_WIDTH-1:0]        axi_in_ar_addr_i  ,
    input  logic [2:0]                       axi_in_ar_prot_i  ,
    input  logic [3:0]                       axi_in_ar_region_i,
    input  logic [7:0]                       axi_in_ar_len_i   ,
    input  logic [2:0]                       axi_in_ar_size_i  ,
    input  logic [1:0]                       axi_in_ar_burst_i ,
    input  logic                             axi_in_ar_lock_i  ,
    input  logic [3:0]                       axi_in_ar_cache_i ,
    input  logic [3:0]                       axi_in_ar_qos_i   ,
    input  logic [AXI_ID_WIDTH-1:0]          axi_in_ar_id_i    ,
    input  logic [AXI_USER_WIDTH-1:0]        axi_in_ar_user_i  ,
    output logic                             axi_in_ar_ready_o ,

    // WRITE DATA CHANNEL
    input  logic                             axi_in_w_valid_i,
    input  logic [AXI_DATA_WIDTH-1:0]        axi_in_w_data_i ,
    input  logic [AXI_STRB_WIDTH-1:0]        axi_in_w_strb_i ,
    input  logic [AXI_USER_WIDTH-1:0]        axi_in_w_user_i ,
    input  logic                             axi_in_w_last_i ,
    output logic                             axi_in_w_ready_o,

    // READ DATA CHANNEL
    output logic                             axi_in_r_valid_o,
    output logic [AXI_DATA_WIDTH-1:0]        axi_in_r_data_o ,
    output logic [1:0]                       axi_in_r_resp_o ,
    output logic                             axi_in_r_last_o ,
    output logic [AXI_ID_WIDTH-1:0]          axi_in_r_id_o   ,
    output logic [AXI_USER_WIDTH-1:0]        axi_in_r_user_o ,
    input  logic                             axi_in_r_ready_i,

    // WRITE RESPONSE CHANNEL
    output logic                             axi_in_b_valid_o,
    output logic [1:0]                       axi_in_b_resp_o ,
    output logic [AXI_ID_WIDTH-1:0]          axi_in_b_id_o   ,
    output logic [AXI_USER_WIDTH-1:0]        axi_in_b_user_o ,
    input  logic                             axi_in_b_ready_i,

    // OUTPUT
    // WRITE ADDRESS CHANNEL
    output logic                             axi_out_aw_valid_o ,
    output logic [AXI_ADDR_WIDTH-1:0]        axi_out_aw_addr_o  ,
    output logic [2:0]                       axi_out_aw_prot_o  ,
    output logic [3:0]                       axi_out_aw_region_o,
    output logic [7:0]                       axi_out_aw_len_o   ,
    output logic [2:0]                       axi_out_aw_size_o  ,
    output logic [5:0]                       axi_out_aw_atop_o  ,
    output logic [1:0]                       axi_out_aw_burst_o ,
    output logic                             axi_out_aw_lock_o  ,
    output logic [3:0]                       axi_out_aw_cache_o ,
    output logic [3:0]                       axi_out_aw_qos_o   ,
    output logic [AXI_ID_WIDTH-1:0]          axi_out_aw_id_o    ,
    output logic [AXI_USER_WIDTH-1:0]        axi_out_aw_user_o  ,
    input  logic                             axi_out_aw_ready_i ,

    // READ ADDRESS CHANNEL
    output logic                             axi_out_ar_valid_o ,
    output logic [AXI_ADDR_WIDTH-1:0]        axi_out_ar_addr_o  ,
    output logic [2:0]                       axi_out_ar_prot_o  ,
    output logic [3:0]                       axi_out_ar_region_o,
    output logic [7:0]                       axi_out_ar_len_o   ,
    output logic [2:0]                       axi_out_ar_size_o  ,
    output logic [1:0]                       axi_out_ar_burst_o ,
    output logic                             axi_out_ar_lock_o  ,
    output logic [3:0]                       axi_out_ar_cache_o ,
    output logic [3:0]                       axi_out_ar_qos_o   ,
    output logic [AXI_ID_WIDTH-1:0]          axi_out_ar_id_o    ,
    output logic [AXI_USER_WIDTH-1:0]        axi_out_ar_user_o  ,
    input  logic                             axi_out_ar_ready_i ,

    // WRITE DATA CHANNEL
    output logic                             axi_out_w_valid_o,
    output logic [AXI_DATA_WIDTH-1:0]        axi_out_w_data_o ,
    output logic [AXI_STRB_WIDTH-1:0]        axi_out_w_strb_o ,
    output logic [AXI_USER_WIDTH-1:0]        axi_out_w_user_o ,
    output logic                             axi_out_w_last_o ,
    input  logic                             axi_out_w_ready_i,

    // READ DATA CHANNEL
    input  logic                             axi_out_r_valid_i,
    input  logic [AXI_DATA_WIDTH-1:0]        axi_out_r_data_i ,
    input  logic [1:0]                       axi_out_r_resp_i ,
    input  logic                             axi_out_r_last_i ,
    input  logic [AXI_ID_WIDTH-1:0]          axi_out_r_id_i   ,
    input  logic [AXI_USER_WIDTH-1:0]        axi_out_r_user_i ,
    output logic                             axi_out_r_ready_o,

    // WRITE RESPONSE CHANNEL
    input  logic                             axi_out_b_valid_i,
    input  logic [1:0]                       axi_out_b_resp_i ,
    input  logic [AXI_ID_WIDTH-1:0]          axi_out_b_id_i   ,
    input  logic [AXI_USER_WIDTH-1:0]        axi_out_b_user_i ,
    output logic                             axi_out_b_ready_o
);

    axi_filter_wr_channel #(
        .AXI_ADDR_WIDTH            (AXI_ADDR_WIDTH     ),
        .AXI_DATA_WIDTH            (AXI_DATA_WIDTH     ),
        .AXI_STRB_WIDTH            (AXI_STRB_WIDTH     ),
        .AXI_ID_WIDTH              (AXI_ID_WIDTH       ),
        .AXI_USER_WIDTH            (AXI_USER_WIDTH     ),
        .NBR_RANGE                 (NBR_RANGE          ),
        .NBR_OUTSTANDING_REQ       (NBR_OUTSTANDING_REQ),
        .AXI_LOOK_BITS             (AXI_LOOK_BITS      )
    ) axi_filter_wr_channel_i (
        .i_clk               (i_clk              ),
        .i_rst_n             (i_rst_n            ),
        .i_scan_ckgt_enable  (i_scan_ckgt_enable ),
        .START_ADDR          (START_ADDR         ),
        .STOP_ADDR           (STOP_ADDR          ),
        // INPUT
        // WRITE ADDRESS CHANNEL
        .axi_in_aw_valid_i    (axi_in_aw_valid_i  ),
        .axi_in_aw_addr_i     (axi_in_aw_addr_i   ),
        .axi_in_aw_prot_i     (axi_in_aw_prot_i   ),
        .axi_in_aw_region_i   (axi_in_aw_region_i ),
        .axi_in_aw_len_i      (axi_in_aw_len_i    ),
        .axi_in_aw_size_i     (axi_in_aw_size_i   ),
        .axi_in_aw_atop_i     (axi_in_aw_atop_i   ),
        .axi_in_aw_burst_i    (axi_in_aw_burst_i  ),
        .axi_in_aw_lock_i     (axi_in_aw_lock_i   ),
        .axi_in_aw_cache_i    (axi_in_aw_cache_i  ),
        .axi_in_aw_qos_i      (axi_in_aw_qos_i    ),
        .axi_in_aw_id_i       (axi_in_aw_id_i     ),
        .axi_in_aw_user_i     (axi_in_aw_user_i   ),
        .axi_in_aw_ready_o    (axi_in_aw_ready_o  ),
        // WRITE DATA CHANNEL
        .axi_in_w_valid_i    (axi_in_w_valid_i   ),
        .axi_in_w_data_i     (axi_in_w_data_i    ),
        .axi_in_w_strb_i     (axi_in_w_strb_i    ),
        .axi_in_w_user_i     (axi_in_w_user_i    ),
        .axi_in_w_last_i     (axi_in_w_last_i    ),
        .axi_in_w_ready_o    (axi_in_w_ready_o   ),
        // WRITE RESPONSE CHANNEL
        .axi_in_b_valid_o    (axi_in_b_valid_o   ),
        .axi_in_b_resp_o     (axi_in_b_resp_o    ),
        .axi_in_b_id_o       (axi_in_b_id_o      ),
        .axi_in_b_user_o     (axi_in_b_user_o    ),
        .axi_in_b_ready_i    (axi_in_b_ready_i   ),
        // OUTPUT
        // WRITE ADDRESS CHANNEL
        .axi_out_aw_valid_o  (axi_out_aw_valid_o ),
        .axi_out_aw_addr_o   (axi_out_aw_addr_o  ),
        .axi_out_aw_prot_o   (axi_out_aw_prot_o  ),
        .axi_out_aw_region_o (axi_out_aw_region_o),
        .axi_out_aw_len_o    (axi_out_aw_len_o   ),
        .axi_out_aw_size_o   (axi_out_aw_size_o  ),
        .axi_out_aw_atop_o   (axi_out_aw_atop_o  ),
        .axi_out_aw_burst_o  (axi_out_aw_burst_o ),
        .axi_out_aw_lock_o   (axi_out_aw_lock_o  ),
        .axi_out_aw_cache_o  (axi_out_aw_cache_o ),
        .axi_out_aw_qos_o    (axi_out_aw_qos_o   ),
        .axi_out_aw_id_o     (axi_out_aw_id_o    ),
        .axi_out_aw_user_o   (axi_out_aw_user_o  ),
        .axi_out_aw_ready_i  (axi_out_aw_ready_i ),
        // WRITE DATA CHANNEL
        .axi_out_w_valid_o   (axi_out_w_valid_o  ),
        .axi_out_w_data_o    (axi_out_w_data_o   ),
        .axi_out_w_strb_o    (axi_out_w_strb_o   ),
        .axi_out_w_user_o    (axi_out_w_user_o   ),
        .axi_out_w_last_o    (axi_out_w_last_o   ),
        .axi_out_w_ready_i   (axi_out_w_ready_i  ),
        // WRITE RESPONSE CHANNEL
        .axi_out_b_valid_i   (axi_out_b_valid_i  ),
        .axi_out_b_resp_i    (axi_out_b_resp_i   ),
        .axi_out_b_id_i      (axi_out_b_id_i     ),
        .axi_out_b_user_i    (axi_out_b_user_i   ),
        .axi_out_b_ready_o   (axi_out_b_ready_o  )
    );

    axi_filter_rd_channel #(
        .AXI_ADDR_WIDTH      (AXI_ADDR_WIDTH     ),
        .AXI_DATA_WIDTH      (AXI_DATA_WIDTH     ),
        .AXI_STRB_WIDTH      (AXI_STRB_WIDTH     ),
        .AXI_ID_WIDTH        (AXI_ID_WIDTH       ),
        .AXI_USER_WIDTH      (AXI_USER_WIDTH     ),
        .NBR_RANGE           (NBR_RANGE          ),
        .NBR_OUTSTANDING_REQ (NBR_OUTSTANDING_REQ),
        .AXI_LOOK_BITS       (AXI_LOOK_BITS      )
    ) axi_filter_rd_channel_i (
        .i_clk               (i_clk              ),
        .i_rst_n             (i_rst_n            ),
        .i_scan_ckgt_enable  (i_scan_ckgt_enable ),
        .START_ADDR          (START_ADDR         ),
        .STOP_ADDR           (STOP_ADDR          ),
        // INPUT
        // READ ADDRESS CHANNEL
        .axi_in_ar_valid_i   (axi_in_ar_valid_i  ),
        .axi_in_ar_addr_i    (axi_in_ar_addr_i   ),
        .axi_in_ar_prot_i    (axi_in_ar_prot_i   ),
        .axi_in_ar_region_i  (axi_in_ar_region_i ),
        .axi_in_ar_len_i     (axi_in_ar_len_i    ),
        .axi_in_ar_size_i    (axi_in_ar_size_i   ),
        .axi_in_ar_burst_i   (axi_in_ar_burst_i  ),
        .axi_in_ar_lock_i    (axi_in_ar_lock_i   ),
        .axi_in_ar_cache_i   (axi_in_ar_cache_i  ),
        .axi_in_ar_qos_i     (axi_in_ar_qos_i    ),
        .axi_in_ar_id_i      (axi_in_ar_id_i     ),
        .axi_in_ar_user_i    (axi_in_ar_user_i   ),
        .axi_in_ar_ready_o   (axi_in_ar_ready_o  ),
        // READ DATA CHANNEL
        .axi_in_r_valid_o    (axi_in_r_valid_o   ),
        .axi_in_r_data_o     (axi_in_r_data_o    ),
        .axi_in_r_resp_o     (axi_in_r_resp_o    ),
        .axi_in_r_last_o     (axi_in_r_last_o    ),
        .axi_in_r_id_o       (axi_in_r_id_o      ),
        .axi_in_r_user_o     (axi_in_r_user_o    ),
        .axi_in_r_ready_i    (axi_in_r_ready_i   ),
        // OUTPUT
        // READ ADDRESS CHANNEL
        .axi_out_ar_valid_o  (axi_out_ar_valid_o ),
        .axi_out_ar_addr_o   (axi_out_ar_addr_o  ),
        .axi_out_ar_prot_o   (axi_out_ar_prot_o  ),
        .axi_out_ar_region_o (axi_out_ar_region_o),
        .axi_out_ar_len_o    (axi_out_ar_len_o   ),
        .axi_out_ar_size_o   (axi_out_ar_size_o  ),
        .axi_out_ar_burst_o  (axi_out_ar_burst_o ),
        .axi_out_ar_lock_o   (axi_out_ar_lock_o  ),
        .axi_out_ar_cache_o  (axi_out_ar_cache_o ),
        .axi_out_ar_qos_o    (axi_out_ar_qos_o   ),
        .axi_out_ar_id_o     (axi_out_ar_id_o    ),
        .axi_out_ar_user_o   (axi_out_ar_user_o  ),
        .axi_out_ar_ready_i  (axi_out_ar_ready_i ),
        // READ DATA CHANNEL
        .axi_out_r_valid_i   (axi_out_r_valid_i  ),
        .axi_out_r_data_i    (axi_out_r_data_i   ),
        .axi_out_r_resp_i    (axi_out_r_resp_i   ),
        .axi_out_r_last_i    (axi_out_r_last_i   ),
        .axi_out_r_id_i      (axi_out_r_id_i     ),
        .axi_out_r_user_i    (axi_out_r_user_i   ),
        .axi_out_r_ready_o   (axi_out_r_ready_o  )
);

endmodule
