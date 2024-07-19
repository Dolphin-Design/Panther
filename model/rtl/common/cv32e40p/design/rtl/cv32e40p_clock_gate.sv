module cv32e40p_clock_gate(
    input  logic clk_i       ,
    input  logic en_i        ,
    input  logic scan_cg_en_i,
    output logic clk_o
);

  clkgating cv32e40p_clkgate 
  (
   .i_clk       ( clk_i        ),
   .i_test_mode ( scan_cg_en_i ),
   .i_enable    ( en_i         ),
   .o_gated_clk ( clk_o        )
  );

endmodule