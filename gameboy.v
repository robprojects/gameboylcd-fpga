`timescale 1ns / 1ps

// GND - BLACK - J3GND
// H-SYNC - BROWN - J3A - P25
// LCD1 - RED - J2D - P23
// LCD0 - ORANGE - J2C - P22
// PIXCLK - YELLOW - J2B - P21
// VSYNC - GREEN - J2A - P20

module gameboy(
 //   output [0:6] led,
	 // lcd
	 output [7:0] d,
	 output rst,
	 output cs,
	 output cd,
	 output rd,
	 output wr,
	 input [1:0] gb_d,
	 input pixclk,
	 input vsync,
	 input hsync
    );

wire clk;
OSCH #(
	.NOM_FREQ("29.56")
) int_osc (
	.STDBY(1'b0),
	.OSC(clk)
);


wire [9:0] lram_wa;
wire lram_we;
wire [1:0] lram_di;
wire [7:0] rrow;
wire line_done;
wire r_row_inc;
wire frame;

gblcd gb0 (
	.clk(clk),
	.pixclk(pixclk),
	.hsync(hsync),
	.vsync(vsync),
	.gb_d(gb_d),
	.lram_wa(lram_wa),
	.lram_we(lram_we),
	.lram_di(lram_di),
	.rrow_out(rrow),
	.line_done(line_done),
	.r_row_inc_out(r_row_inc),
	.frame_out(frame),
	.even_line_out(even_line)
);

wire [9:0] lram_ra;
wire [1:0] lram_do;

lineram lram0 (
	.clk(clk),
	.we(lram_we),
	.wa(lram_wa),
	.ra(lram_ra),
	.di(lram_di),
	.do1(lram_do)
);

assign led = lram_ra;

wire pix_out_valid;
wire [15:0] pix_out;

upscalar upscalar0 (
	.clk(clk),
	.lram_do(lram_do),
	.lram_ra(lram_ra),
	.even_line(even_line),
	.rrow(rrow),
	.r_row_inc(r_row_inc),
	.pix_out_valid(pix_out_valid),
	.pix_out(pix_out),
	.line_done(line_done),
	.frame(frame)
);

lcddrv lcd0 (
	.clk(clk),
	.d(d),
	.rst(rst),
	.cs(cs),
	.cd(cd),
	.rd(rd),
	.wr(wr),
	.pixvalid(pix_out_valid),
	.pix(pix_out),
	.frame(frame)
);

endmodule
