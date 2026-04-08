module visualizer(
		input pixel_clk,
		input reset,
		output [3:0] VGA_R,
		output [3:0] VGA_G,
		output [3:0] VGA_B,
		output VGA_HS,
		output VGA_VS,
		input [23:0] f0,
		input [23:0] f1,
		input [23:0] f2,
		input [23:0] f3,
		input [23:0] f4,
		input [23:0] f5,
		input [23:0] f6,
		input [23:0] f7,
		input [23:0] f8,
		input [23:0] f9,
		input [23:0] f10,
		input [23:0] f11,
		input [23:0] f12,
		input [23:0] f13,
		input [23:0] f14,
		input [23:0] f15,
		input done
	);
	
	// despite needding all time domain points for the FFT (16 points), nyquist theorem says that you can only represet frequencies up to f/2, and everything more than that is just a direct mirror.
	// hence why the bars are mirroed
	
	// each bar represents a freqency range of fs/16 Hz wide. since fs = 3.072MHz/64 = 48 kHz. each column represents 3kHz

	wire [31:0] column;
	wire [31:0] row;
	wire disp_ena;

	// from lab 5
	vga_controller controller_inst(
		.pixel_clk(pixel_clk),
		.reset_n(reset),
		.h_sync(VGA_HS),
		.v_sync(VGA_VS),
		.disp_ena(disp_ena),
		.column(column),
		.row(row)
	);

	// latch on done
	reg [23:0] f1_reg, f2_reg, f3_reg, f4_reg, f5_reg, f6_reg, f7_reg;

	reg done_s1, done_s2, done_s3;
always @(posedge pixel_clk) begin
    done_s1 <= done;
    done_s2 <= done_s1;
    done_s3 <= done_s2;
end

	// rising edge detect 
	wire done_rising = done_s2 & ~done_s3;

	// latch data on synchronized done
	always @(posedge pixel_clk) begin
		 if (done_rising) begin
			  f1_reg <= f1;
			  f2_reg <= f2;
			  f3_reg <= f3;
			  f4_reg <= f4;
			  f5_reg <= f5;
			  f6_reg <= f6;
			  f7_reg <= f7;
		 end
	end



	// latch during blanking and clamp negatives
	reg [23:0] f1_d, f2_d, f3_d, f4_d, f5_d, f6_d, f7_d;


	reg vblank;
	always @(posedge pixel_clk) begin
		 if (row == 479 && !disp_ena)
			  vblank <= 1;
		 else if (row == 0)
			  vblank <= 0;
	end

	always @(posedge pixel_clk) begin
		 if (vblank) begin
			  f1_d <= f1_reg[23] ? 24'b0 : f1_reg;
			  f2_d <= f2_reg[23] ? 24'b0 : f2_reg;
			  f3_d <= f3_reg[23] ? 24'b0 : f3_reg;
			  f4_d <= f4_reg[23] ? 24'b0 : f4_reg;
			  f5_d <= f5_reg[23] ? 24'b0 : f5_reg;
			  f6_d <= f6_reg[23] ? 24'b0 : f6_reg;
			  f7_d <= f7_reg[23] ? 24'b0 : f7_reg;
		 end
	end

	// scale to bar heights
	wire [47:0] bh1 = (f1_d * 48'd480) >> 10;
	wire [47:0] bh2 = (f2_d * 48'd480) >> 10;
	wire [47:0] bh3 = (f3_d * 48'd480) >> 10;
	wire [47:0] bh4 = (f4_d * 48'd480) >> 10;
	wire [47:0] bh5 = (f5_d * 48'd480) >> 10;
	wire [47:0] bh6 = (f6_d * 48'd480) >> 10;
	wire [47:0] bh7 = (f7_d * 48'd480) >> 10;

	// bar_top = 480 - bar_height
	wire [31:0] bt1 = (bh1 >= 480) ? 0 : (480 - bh1);
	wire [31:0] bt2 = (bh2 >= 480) ? 0 : (480 - bh2);
	wire [31:0] bt3 = (bh3 >= 480) ? 0 : (480 - bh3);
	wire [31:0] bt4 = (bh4 >= 480) ? 0 : (480 - bh4);
	wire [31:0] bt5 = (bh5 >= 480) ? 0 : (480 - bh5);
	wire [31:0] bt6 = (bh6 >= 480) ? 0 : (480 - bh6);
	wire [31:0] bt7 = (bh7 >= 480) ? 0 : (480 - bh7);

	// which bin is active at this column (these are mirrored)
	wire [2:0] bin_sel = (column < 46)  ? 3'd1 :(column < 92)  ? 3'd2 :(column < 138) ? 3'd3 :(column < 184) ? 3'd4 :(column < 230) ? 3'd5 :
	(column < 276) ? 3'd6 :(column < 320) ? 3'd7 :(column < 366) ? 3'd7 :(column < 412) ? 3'd6 :
	(column < 458) ? 3'd5 :(column < 504) ? 3'd4 :(column < 550) ? 3'd3 :(column < 596) ? 3'd2 :3'd1;

	// is current row inside the bar for this bin?
	wire active =(bin_sel == 3'd1) ? (row >= bt1) :(bin_sel == 3'd2) ? (row >= bt2) :(bin_sel == 3'd3) ? (row >= bt3) :(bin_sel == 3'd4) ? (row >= bt4) :(bin_sel == 3'd5) ? (row >= bt5) :(bin_sel == 3'd6) ? (row >= bt6) :(row >= bt7);

	// rainbow colors per bin, roygbiv :)
	wire [3:0] bar_r = (bin_sel == 3'd1) ? 4'hF :(bin_sel == 3'd2) ? 4'hF :(bin_sel == 3'd3) ? 4'hF :(bin_sel == 3'd4) ? 4'h0 :(bin_sel == 3'd5) ? 4'h0 :(bin_sel == 3'd6) ? 4'h5 :4'hA;

	wire [3:0] bar_g = (bin_sel == 3'd1) ? 4'h0 :(bin_sel == 3'd2) ? 4'h7 :(bin_sel == 3'd3) ? 4'hF :(bin_sel == 3'd4) ? 4'hF :(bin_sel == 3'd5) ? 4'h0 :(bin_sel == 3'd6) ? 4'h0 :4'h0;

	wire [3:0] bar_b = (bin_sel == 3'd1) ? 4'h0 :(bin_sel == 3'd2) ? 4'h0 :(bin_sel == 3'd3) ? 4'h0 :(bin_sel == 3'd4) ? 4'h0 :(bin_sel == 3'd5) ? 4'hF :(bin_sel == 3'd6) ? 4'hF :4'hF;

	assign VGA_R = (disp_ena && active) ? bar_r : 4'h0;
	assign VGA_G = (disp_ena && active) ? bar_g : 4'h0;
	assign VGA_B = (disp_ena && active) ? bar_b : 4'h0;

endmodule