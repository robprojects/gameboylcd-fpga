`timescale 1ns / 1ps

module lineram(
    input clk,
    input we,
    input [9:0] wa,
    input [9:0] ra,
    input [1:0] di,
    output [1:0] do1
    );

	reg [1:0] ram [1023:0];
	reg [1:0] out_reg;

	always @(posedge clk)
	begin
		if (we)
			ram[wa] <= di;
		out_reg <= ram[ra];
	end

	assign do1 = out_reg;

endmodule
