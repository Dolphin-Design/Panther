`ifndef APB_TIMER_UNIT_PKG
`define APB_TIMER_UNIT_PKG


package apb_timer_unit_pkg;

    localparam logic [5:0] CFG_REG_LO          = 6'h0 ;
    localparam logic [5:0] CFG_REG_HI          = 6'h4 ;
    localparam logic [5:0] TIMER_VAL_LO        = 6'h8 ;
    localparam logic [5:0] TIMER_VAL_HI        = 6'hC ;
    localparam logic [5:0] TIMER_CMP_LO        = 6'h10;
    localparam logic [5:0] TIMER_CMP_HI        = 6'h14;
    localparam logic [5:0] TIMER_START_LO      = 6'h18;
    localparam logic [5:0] TIMER_START_HI      = 6'h1C;
    localparam logic [5:0] TIMER_RESET_LO      = 6'h20;
    localparam logic [5:0] TIMER_RESET_HI      = 6'h24;


    localparam ENABLE_BIT                  =  'd0;
    localparam RESET_BIT                   =  'd1;
    localparam IRQ_BIT                     =  'd2;
    localparam IEM_BIT                     =  'd3;
    localparam CMP_CLR_BIT                 =  'd4;
    localparam ONE_SHOT_BIT                =  'd5;
    localparam PRESCALER_EN_BIT            =  'd6;
    localparam REF_CLK_EN_BIT              =  'd7;
    localparam PRESCALER_START_BIT         =  'd8;
    localparam PRESCALER_STOP_BIT          =  'd15;
    localparam MODE_64_BIT                 =  'd31;

endpackage


`endif
