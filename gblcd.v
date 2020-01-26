`timescale 1ns / 1ps

module gblcd(
    input pixclk,
    input hsync,
    input vsync,
    input [1:0] gb_d,
    input clk,
    output [9:0] lram_wa,
    output lram_we,
    output [1:0] lram_di,
    output [7:0] rrow_out,
	 output r_row_inc_out,
    input line_done,
	 output frame_out,
	 output even_line_out
    );
reg [7:0] col;
reg [7:0] row;


reg [7:0] rrow;

reg frame;
reg r_row_inc;

assign rrow_out = rrow;
assign r_row_inc_out = r_row_inc;
assign frame_out = frame;



initial begin

	col = 0;
	row = 0;
	
	rrow = 0;
end

// game boy screen data

/*reg [1:0] gb_d_r;
reg [1:0] gb_d_r2;
reg [1:0] gb_d_r3;

reg pixclk_r, pixclk_r2, pixclk_r3;
reg vsync_r, vsync_r2, vsync_r3;
reg hsync_r, hsync_r2, hsync_r3, hsync_r4, hsync_r5;
*/
// synchronize and edge detect on pixclk
/*
always @(posedge clk) begin
	gb_d_r <= gb_d;
	gb_d_r2 <= gb_d_r;
	gb_d_r3 <= gb_d_r2;
	pixclk_r <= pixclk;
	pixclk_r2 <= pixclk_r;
	pixclk_r3 <= pixclk_r2;
	vsync_r <= vsync;
	vsync_r2 <= vsync_r;
	vsync_r3 <= vsync_r2;
	hsync_r <= hsync;
	hsync_r2 <= hsync_r;
	hsync_r3 <= hsync_r2;
		hsync_r4 <= hsync_r3;
				hsync_r5 <= hsync_r4;
end
*/

reg col_en, col_en_r;
reg col_rst;



// col counter
/*
always @(pixclk_r3, pixclk_r2, vsync_r3, vsync_r2, hsync_r2, hsync_r5, hsync_r, col) begin
	col_rst = 1'b0;
	col_en = 1'b0;
	frame = 1'b0;
	
	if (pixclk_r3 == 1'b0 && pixclk_r2 == 1'b1) begin
		if (hsync_r5 == 1'b1 && col != 0) begin
			col_rst = 1'b1;
			col_en = 1'b1;
		end else
			col_en = 1'b1;
	end
	
	if (vsync_r3 == 1'b0 && vsync_r2 == 1'b1) begin
		frame = 1'b1;
	end
	
end
*/

reg [1:0] gb_d_pixclk;
reg hsync_pixclk;
reg pix_t;

initial begin
	pix_t = 1'b0;
end

// capture in pixclk domain
always @(posedge pixclk) begin
	gb_d_pixclk <= gb_d;
	hsync_pixclk <= hsync;
	pix_t <= !pix_t;
end
 
// sync to clk

reg [1:0] gb_d_r, gb_d_r2, gb_d_r3;
reg pix_t_r, pix_t_r2, pix_t_r3;
reg hsync_r, hsync_r2, hsync_r3, hsync_r4, hsync_r5;
reg vsync_r, vsync_r2, vsync_r3;

always @(posedge clk) begin
	gb_d_r <= gb_d_pixclk;
	gb_d_r2 <= gb_d_r;
	gb_d_r3 <= gb_d_r2;
	pix_t_r <= pix_t;
	pix_t_r2 <= pix_t_r;
	pix_t_r3 <= pix_t_r2;
	hsync_r <= hsync_pixclk;
	hsync_r2 <= hsync_r;
	hsync_r3 <= hsync_r2;
	hsync_r4 <= hsync_r3;
	hsync_r5 <= hsync_r4;
	
	vsync_r <= vsync;
	vsync_r2 <= vsync_r;
	vsync_r3 <= vsync_r2;
end

always@(pix_t_r2, pix_t_r3, hsync_r3, vsync_r2, vsync_r3, col) begin
   col_en <= 1'b0;
	frame <= 1'b0;
	col_rst <= 1'b0;
	
	if (pix_t_r2 != pix_t_r3) begin
		// new pixel
		col_en <= 1'b1;
		if (hsync_r2 == 1'b1 && col != 0) begin
			col_rst <= hsync_r5;
		end
	end
	
	if (vsync_r3 == 1'b0 && vsync_r2 == 1'b1) begin
		frame <= 1'b1;
	end
end

// col_rst from hsync
// col_en from pixclk
// frame from vsync rising edge
// gbd_r2 is lram_di

always @(posedge clk) begin
	if (col_rst == 1'b1) begin
		col <= 8'h00;
	end else if (col_en == 1'b1)
		col <= col + 1;
		
	col_en_r <= col_en;
end

reg row_inc;

always @(posedge clk) begin
	if (col == (160-2) && col_en == 1'b1)
		row_inc <= 1'b1;
	else
		row_inc <= 1'b0;
end

reg [7:0] row_r;
reg [7:0] row_r2;




assign lram_wa = {row[1:0], col[7:0]};

assign lram_we = col_en_r;

assign lram_di = gb_d_r2;



// pipeline fill/flush
parameter S_FFWAIT = 4'b0000;
parameter S_FFLINE = 4'b0001;
parameter S_FFXLINE = 4'b0010;
parameter S_FFWAITX = 4'b0011;
parameter S_FILL = 4'b0100;
parameter S_FLUSH = 4'b0101;
parameter S_FLUSH2 = 4'b0110;
parameter S_FLUSHX = 4'b0111;
parameter S_FLUSHX2 = 4'b1000;

reg [3:0] fstate;
reg [3:0] skipcnt;

reg [1:0] fillcnt;

initial begin
	fstate = S_FILL;
	skipcnt = 0;
	fillcnt = 0;
end

reg flush_inc;

// avoid doubling every 3rd line to get 144->240
always @(posedge clk) begin
	if (frame)
		skipcnt <= 0;
	else if (row_inc | flush_inc)
		if (skipcnt == 2)
			skipcnt <= 0;
		else
			skipcnt <= skipcnt + 1;

end

always @(posedge clk) begin
	if (frame)
		row <= 0;
	else if (row_inc | flush_inc) begin
		row <= row + 1;
		row_r <= row;
		//row_r2 <= row_r;
		//rrow <= row_r2;
		rrow <= row_r;
	end
end

always @(posedge clk) begin
	if (frame)
		fillcnt <= 0;
	else if (row_inc) fillcnt <= fillcnt + 1;
end

always @(posedge clk) begin
	if (frame)
		fstate <= S_FILL;
	else begin	
		case (fstate)
			S_FILL: begin
				if (fillcnt == 1) fstate <= S_FFWAIT;
			end
			S_FFWAIT: begin
				if (row_inc)
					if (rrow == 141)
						fstate <= S_FLUSH2;
					else 
						fstate <= S_FFLINE;
			end
			S_FFWAITX: begin
				if (row_inc)
					if (rrow == 141)
						fstate <= S_FLUSH2;
					else 
						fstate <= S_FFLINE;
			end
			S_FLUSH: begin
				fstate <= S_FLUSH2;
			end
			S_FLUSH2: begin
				if (line_done)
					if (rrow == 144)
						fstate <= S_FILL; // finished
					else if (skipcnt == 2)
						fstate <= S_FLUSH;
					else
						fstate <= S_FLUSHX;
			end
			S_FLUSHX: begin
				fstate <= S_FLUSHX2;
			end
			S_FLUSHX2: begin
				if (line_done)
					if (rrow == 144)
						fstate <= S_FILL; // finished
					else
						fstate <= S_FLUSH;
			end
			S_FFLINE:
				if (line_done == 1'b1)
					if (skipcnt == 2)
						fstate <= S_FFWAIT;
					else
						fstate <= S_FFXLINE; // fixme always do xtra line
			S_FFXLINE:
				fstate <= S_FFWAITX;
		endcase
	end
end

reg even_line;

always @(fstate, row_inc) begin
	r_row_inc = 1'b0;
	even_line = 1'b0;
	flush_inc = 1'b0;
	case (fstate)
		S_FFWAIT: begin
			r_row_inc = (row_inc);
		end
		S_FFWAITX: begin
			r_row_inc = (row_inc);
			even_line = 1'b1;
		end
		S_FFLINE: begin
			
		end
		S_FFXLINE: begin
			r_row_inc = 1'b1;
		end
		S_FLUSH: begin
			flush_inc = 1'b1;
			r_row_inc = 1'b1;
		end
		S_FLUSHX: begin
			r_row_inc = 1'b1;
			even_line = 1'b1;
		end
	endcase
end

assign even_line_out = even_line;

endmodule
