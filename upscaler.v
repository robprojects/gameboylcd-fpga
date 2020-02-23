`timescale 1ns / 1ps

module upscalar(
    input clk,
    input [1:0] lram_do,
    output [9:0] lram_ra,
    input even_line,
    input [7:0] rrow,
    input r_row_inc,
    output pix_out_valid,
    output [15:0] pix_out,
    output line_done,
    input frame
    );

reg [3:0] rstate;
reg [7:0] rcol;
reg r_inc;

reg [1:0] col_offset;
reg [1:0] row_offset;

parameter S_WAIT = 4'b0000;
parameter S_LP = 4'b0001;
parameter S_LB = 4'b0010;
parameter S_LA = 4'b0011;
parameter S_LD = 4'b0100;
parameter S_LB2 = 4'b0101;
parameter S_WS = 4'b0110;
parameter S_WS1 = 4'b0111;
parameter S_WS2 = 4'b1000;
parameter S_WS3 = 4'b1001;
parameter S_WS4 = 4'b1010;

initial begin

	rstate = S_WAIT;
	rcol = 0;

end

reg [9:0] read_address;

// add offsets
always @(col_offset, row_offset, rcol, rrow) begin
	read_address[9:8] <= rrow[1:0] + row_offset;
	read_address[7:0] <= rcol + {{6{col_offset[1]}}, col_offset[1:0]};
end

assign lram_ra = read_address;

always @(posedge clk) begin
   if (r_row_inc || frame)
		rcol <= 0;
	else if (r_inc == 1'b1)
		rcol <= rcol + 1;
end

reg [1:0] lp;
reg [1:0] lb;
reg [1:0] la;
reg [1:0] ld;
reg [1:0] lp_r;

always @(posedge clk) begin
   if (frame)
		rstate <= S_WAIT;
	else begin
		case (rstate)
			S_LP: begin
				rstate <= S_LB;
			end
			S_LB: begin
				lp <= lram_do;
				lp_r <= lp;
				rstate <= S_LA;
			end
			S_LA: begin
				rstate <= S_LD;
				lb <= lram_do;
			end
			S_LD: begin
				la <= lram_do;
				rstate <= S_WS;
			end
			S_WS: begin
				rstate <= S_WS1;
				ld <= lram_do;
			end
			S_WS1: rstate <= S_WS2;
			S_WS2: rstate <= S_WS3;
			S_WS3: rstate <= S_WS4;
			S_WS4: begin
				if (rcol == (160-1))
						rstate <= S_WAIT;
					else
						rstate <= S_LP;
			end
			S_WAIT: begin
				if (r_row_inc == 1'b1)
					rstate <= S_LP;
			end
		endcase
	end
end

reg [1:0] c_a;
reg [1:0] c_b;
reg [1:0] c_c;
reg [1:0] c_d;
reg [1:0] c_p;

reg a_valid;
reg b_valid;
reg c_valid;
reg d_valid;

reg a_valid_r;
reg b_valid_r;
reg c_valid_r;
reg d_valid_r;

always @(rrow, rcol) begin
	a_valid = 1'b1;
	b_valid = 1'b1;
	c_valid = 1'b1;
	d_valid = 1'b1;
	
	if (rrow == 0) a_valid = 1'b0;
	if (rrow == (144-1)) d_valid = 1'b0;
	if (rcol == 0) c_valid = 1'b0;
	if (rcol == (160-1)) d_valid = 1'b0;
end

always @(posedge clk) begin
	a_valid_r <= a_valid;
	b_valid_r <= b_valid;
	c_valid_r <= c_valid;
	d_valid_r <= d_valid;
end

reg pixvalid;

// mux in
always @(rstate, lp, la, lb, ld, rrow, rcol, lram_do, lp_r, a_valid_r, b_valid_r, c_valid_r, d_valid_r) begin
	c_p = lp;
	if (rstate == S_WS)
		c_d = lram_do;
	else
		c_d = ld;
	
	c_a = la;
	c_b = lb;
	c_c = lp_r;
	
	if (a_valid_r == 1'b0) c_a = c_p;
	if (d_valid_r == 1'b0) c_d = c_p;
	if (c_valid_r == 1'b0) c_c = c_p;
	if (b_valid_r == 1'b0) c_b = c_p;
end

reg [1:0] pix_1;
reg [1:0] pix_2;
reg [1:0] pix_3;
reg [1:0] pix_4;

reg [1:0] pix_o;

// compute pixels
always @(c_a, c_d, c_c, c_b, c_p) begin
	// 1 and 2 are first row
	pix_1 = c_p;
	pix_2 = c_p;
	// 3 and 4 are second row
	pix_3 = c_p;
	pix_4 = c_p;

	if (c_c == c_a && c_c != c_d && c_a != c_b) pix_1 = c_a;
	if (c_a == c_b && c_a != c_c && c_b != c_d) pix_2 = c_b;
	if (c_d == c_c && c_d != c_b && c_c != c_a) pix_3 = c_c;
	if (c_b == c_d && c_b != c_a && c_d != c_c) pix_4 = c_d;
	
end

// register valid pixels
reg [1:0] pix_1_r;
reg pixvalid_r;

always @(posedge clk) begin
	if (pixvalid == 1'b1)
		pix_1_r <= pix_o;
		
	pixvalid_r <= pixvalid;
end

assign pix_out_valid = pixvalid_r;

reg [15:0] pix_out_p;

always @(pix_1_r) begin
	case(pix_1_r)
		2'b00 : pix_out_p <= 16'b1001010111000001;
		2'b01 : pix_out_p <= 16'b1000010101000001;
		2'b10 : pix_out_p <= 16'b0010101100000101;
		2'b11 : pix_out_p <= 16'b0000100110100001;
	endcase
end;

assign pix_out = pix_out_p;


reg line_d;

always @(rstate, pix_1, pix_2, pix_3, pix_4, even_line) begin
	r_inc = 1'b0;
	col_offset = 2'b00;
	row_offset = 2'b00;
	pixvalid = 1'b0;
	line_d = 1'b0;
	pix_o = pix_1;
	case (rstate)
		S_LB: begin
			col_offset = 2'b01;
		end
		S_LB2: begin
			col_offset = 2'b01;
		end	
		S_LA: begin
			row_offset = 2'b11;
		end
		S_LD: begin
			row_offset = 2'b01;
		end
		S_WS : begin
			pixvalid = 1'b1;
			if (even_line)
				pix_o = pix_3;
			else
				pix_o = pix_1;
		end
		S_WS4 : begin
			pixvalid = 1'b1;
			if (even_line)
				pix_o = pix_4;
			else
				pix_o = pix_2;
			r_inc = 1'b1;
		end
		S_WAIT : line_d = 1'b1;
	endcase
end

assign line_done = line_d;

endmodule
