`timescale 1ns / 1ps

module gameboy_tb;

	// Inputs
	reg clk;

	// Outputs
	wire [0:6] led;
	wire [7:0] lcd_d;
	wire lcd_rst;
	wire lcd_cs;
	wire lcd_cd;
	wire lcd_rd;
	wire lcd_wr;
	
	reg pixclk;
	reg vsync;
	reg hsync;
	reg [1:0] gb_d;

	// Instantiate the Unit Under Test (UUT)
	gameboy uut (
		.clk(clk), 
		.led(led), 
		.d(lcd_d), 
		.rst(lcd_rst), 
		.cs(lcd_cs), 
		.cd(lcd_cd), 
		.rd(lcd_rd), 
		.wr(lcd_wr),
		.gb_d(gb_d),
		.pixclk(pixclk),
		.hsync(hsync),
		.vsync(vsync)
	);

	integer p=0;
	integer line=0;

	integer file;
	integer ofile;
	integer rawval;

	integer tmp;

	initial begin
		// open test file
		file = $fopen("gameboy_a.pgm", "r");
		
		ofile = $fopen("gameboy_o.ppm", "w");
	
		// Initialize Inputs
		clk = 0;
		pixclk = 0;
		vsync = 0;
		hsync = 0;
		gb_d = 2'b00;

		// Wait 100 ns for global reset to finish
		#10000;
        
		// Add stimulus here
		
		for (line = 0; line<144; line = line+1) begin
			if (line==0)
				vsync = 1;
			else
				vsync = 0;
				
			// one horizontal line
			hsync = 1;
			tmp = $fscanf(file, "%d", rawval);
			gb_d = 2'b00;
			if (rawval > 128) begin
				gb_d[1] = 1'b1;
				rawval = rawval - 128;
			end
			if (rawval > 64) begin
				gb_d[0] = 1'b1;
			end
			#500;
			pixclk = 1;
			#100;
			pixclk = 0;
			#500;
			hsync = 0;
			for (p=1; p<160; p=p+1) begin
				// loop over line of pixels
				tmp = $fscanf(file, "%d", rawval);
				gb_d = 2'b00;
				if (rawval > 128) begin
					gb_d[1] = 1'b1;
					rawval = rawval - 128;
				end
				if (rawval > 64) begin
					gb_d[0] = 1'b1;
				end
				//gb_d = p;
				#5;
				pixclk = 1;
				#100;
				pixclk = 0;
				#95;
			end
			// dead time 70us
			#70000;
		end
	end
	
	reg dump_data;
	reg msb;
	reg [7:0] lsb_val;
	reg [15:0] pix;
	integer pixcnt;
	
	initial begin
		dump_data = 0;
		msb = 0;
		pixcnt = 0;
	end
		
	// capture image data
	always @(posedge lcd_wr) begin
	
		// detect write mem command
		if (lcd_d == 8'h2c && lcd_cd == 1'b0) begin
			dump_data <= 1;
			$fwrite(ofile, "P3\n320\n240\n63\n");
		end
		
		if (dump_data) begin
			if (msb) begin
				pix = {lsb_val, lcd_d};
				$fwrite(ofile, "%d %d %d\n",
					{pix[15:11], 1'b0}, pix[10:5], {pix[4:0], 1'b0});
				pixcnt = pixcnt + 1;
			end else
				lsb_val <= lcd_d;
			
			msb <= !msb;
		end
		
		if (dump_data && pixcnt == (320*240)) begin
			dump_data = 0;
			$fclose(ofile);
		end
	end
	
	always
		#10 clk = !clk;
      
endmodule

