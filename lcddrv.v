`timescale 1ns / 1ps

module lcddrv(
    input clk,
    output rst,
    output cs,
    output cd,
    output rd,
    output wr,
    output [7:0] d,
    input pixvalid,
    input [15:0] pix,
	 input frame
    );

reg [31:0] count;

parameter S_INIT = 4'b0000;
parameter S_DECODE = 4'b0001;
parameter S_DELAY = 4'b0010;
parameter S_WRITE1 = 4'b0011;
parameter S_WRITE2 = 4'b0100;
parameter S_END = 4'b0101;
parameter S_PAUSE = 4'b0110;
parameter S_LSB2 = 4'b0111;
parameter S_MSB1 = 4'b1000;
parameter S_MSB2 = 4'b1001;
parameter S_LSB1 = 4'b1010;
parameter S_WR1 = 4'b1011;
parameter S_WR2 = 4'b1100;

reg [3:0] state;

wire [6:0] romaddr;
reg [9:0] romdata;

reg [6:0] pc;
reg pc_en, cnt_rst, cnt_en;

reg [9:0] inst;

initial begin
	state = S_INIT;
	pc = 0;
	count = 0;
end

wire [7:0] count_low;
wire [7:0] count_high;

assign count_low = count[7:0];
assign count_high = count[22:15];

// SIM ONLY
//assign count_low = count[7:0];
//assign count_high = count[7:0];

always @(posedge clk) begin

		case (state)
			S_INIT: if (count_high == 8'hc0) // c0 = 200ms
							state <= S_DECODE;
			S_DECODE: if (romdata[9] == 1'b0)
								state <= S_WRITE1;
						 else
							if (romdata[8] == 1'b0)
								state <= S_DELAY;
							else
								state <= S_END;
			S_DELAY: if (count_high == inst[7:0])
								state <= S_DECODE;
			S_WRITE1: if (count_low == 8'h08) state <= S_WRITE2;
			S_WRITE2: if (count_low == 8'h10) state <= S_PAUSE;
			S_PAUSE : if (count_low == 8'h18) state <= S_DECODE;
			S_END: state <= S_WR1;
			S_WR1 : state <= S_WR2;
			S_WR2 : state <= S_LSB1;
			S_LSB1: /*if (count_low == 8'h08)*/ begin
				if (pixvalid) state <= S_LSB2;
				else if (frame) state <= S_WR1;
			end
			S_LSB2: /*if (count_low == 8'h10)*/ state <= S_MSB1;
			S_MSB1: /*if (count_low == 8'h18)*/ state <= S_MSB2;
			S_MSB2: /*if (count_low == 8'h20)*/ state <= S_LSB1;
		endcase
end

reg lcd_rst, lcd_cd, lcd_cs, lcd_wr, lcd_rd;
reg [7:0] lcd_d;

reg pc_rst;

assign rst = lcd_rst;
assign d = lcd_d;
assign cd = lcd_cd;
assign cs = lcd_cs;
assign wr = lcd_wr;
assign rd = lcd_rd;

always @(state, inst, pix) begin
	lcd_rst = 1'b1;
	pc_en = 1'b0;
	lcd_d = 8'h00;
	lcd_cd = 1'b0;
	lcd_cs = 1'b1;
	lcd_wr = 1'b1;
	lcd_rd = 1'b1;
	cnt_rst = 1'b0;
	cnt_en = 1'b0;
	pc_rst = 1'b0;
	
	case (state)
		S_INIT: begin
			lcd_rst = 1'b0;
			cnt_en = 1'b1;
		end
		S_DECODE: begin
			pc_en = 1'b1;
			cnt_rst = 1'b1;
		end
		S_DELAY: begin
			cnt_en = 1'b1;
		end
		S_WRITE1: begin
			lcd_d = inst[7:0];
			lcd_cd = ~inst[8];
			lcd_wr = 1'b0;
			lcd_cs = 1'b0;
			cnt_en = 1'b1;
		end
		S_WRITE2: begin
			lcd_d = inst[7:0];
			lcd_cd = ~inst[8];
			lcd_wr = 1'b1;
			lcd_cs = 1'b0;
			cnt_en = 1'b1;
		end
		S_PAUSE: begin
			cnt_en = 1'b1;
		end
		S_WR1: begin
			lcd_d = 8'h2c;
			lcd_cd = 1'b0;
			lcd_wr = 1'b0;
			lcd_cs = 1'b0;
		end
		S_WR2: begin
			lcd_d = 8'h2c;
			lcd_cd = 1'b0;
			lcd_wr = 1'b1;
			lcd_cs = 1'b0;
		end
		S_END : begin
			pc_rst = 1'b1;
			cnt_rst = 1'b1;
		end
		S_LSB1 : begin
			lcd_d = pix[15:8];
			lcd_cs = 1'b0;
			lcd_wr = 1'b0;
			lcd_cd = 1'b1;
			cnt_en = 1'b1;
		end
		S_LSB2 : begin
			lcd_d = pix[15:8];
			lcd_cs = 1'b0;
			lcd_wr = 1'b1;
			lcd_cd = 1'b1;
			cnt_en = 1'b1;
		end
		S_MSB1 : begin
			lcd_d = pix[7:0];
			lcd_cs = 1'b0;
			lcd_wr = 1'b0;
			lcd_cd = 1'b1;
			cnt_en = 1'b1;
		end
		S_MSB2 : begin
			lcd_d = pix[7:0];
			lcd_cs = 1'b0;
			lcd_wr = 1'b1;
			lcd_cd = 1'b1;
			cnt_en = 1'b1;
		end
	endcase
end

// delay counter
always @ (posedge clk)
begin
	if (cnt_rst)
		count <= 0;
	if (cnt_en)
		count <= count + 1;
end

//assign led = {4'b0000, state};

// instruction register
always @(posedge clk) begin
	if (pc_en) inst <= romdata;
end

// program counter
always @(posedge clk) begin
   if (pc_rst) pc <= 0;
	else if (pc_en) pc <= pc + 1; 
end

assign romaddr = pc;

// command ROM
always @(posedge clk) begin
	case (romaddr)
	// DELAY 120ms
		7'h00: romdata <= 10'h2c0;
	// soft rest
		7'h01: romdata <= 10'h101;
		// delay 50ms
		7'h02: romdata <= 10'h230;
		// display off
		7'h03: romdata <= 10'h128;
	// LCD_POWER1
		//7'h04: romdata <= 10'h1c0;
		//7'h05: romdata <= 10'h023;
	// LCD_POWER2
		//7'h06: romdata <= 10'h1c1;
		//7'h07: romdata <= 10'h010;
	// VCOM1
		//7'h08: romdata <= 10'h1c5;
	   //7'h09: romdata <= 10'h03e;
		//7'h0a: romdata <= 10'h028;
	// VCOM2
		//7'h0b: romdata <= 10'h1c7;
		//7'h0c: romdata <= 10'h086;
		
		//7'h0d: romdata <= 10'h230;
		
				// MADCTL
		7'h04: romdata <= 10'h136;
		7'h05: romdata <= 10'h00a; /// 0x048 portrait
		
		// column address
		7'h06: romdata <= 10'h12a;
		7'h07: romdata <= 10'h000;
		7'h08: romdata <= 10'h000;
		7'h09: romdata <= 10'h001;
		7'h0a: romdata <= 10'h03f;
		
	// page address
		7'h0b: romdata <= 10'h12b;
		7'h0c: romdata <= 10'h000;
		7'h0d: romdata <= 10'h000;
		7'h0e: romdata <= 10'h000;
		7'h0f: romdata <= 10'h0ef;

		
		// pixel format
		7'h10: romdata <= 10'h13a;
		7'h11: romdata <= 10'h055;
		
		// DELAY 120ms
		7'h12: romdata <= 10'h2c0;
	// frame rate
		//7'h12: romdata <= 10'h1b1;
		//7'h13: romdata <= 10'h000;
		//7'h14: romdata <= 10'h01b;	
	// entry mode set
	   7'h13: romdata <= 10'h1b7;	
		7'h14: romdata <= 10'h007;		

	// sleep out
	   7'h15: romdata <= 10'h111;
		7'h16 : romdata <= 10'h000;
	// DELAY 120ms
		7'h17: romdata <= 10'h2c0;
	// display on
		7'h18 : romdata <= 10'h129;
		7'h19 : romdata <= 10'h000;
	// DELAY 120ms
		7'h1a: romdata <= 10'h2c0;

	// set address window

		//7'h1a : romdata <= 10'h100;
		//7'h1b : romdata <= 10'h100;
		
	   
	
	// GRAM write
		7'h1b: romdata <= 10'h12c;
		
	// END
		7'h1c: romdata <= 10'h300;
	endcase
end

endmodule
