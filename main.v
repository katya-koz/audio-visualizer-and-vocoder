module main (
	input  CLOCK_50,
	input  MIC_SD,
	input  reset,
	output MIC_BCLK,
	output MIC_LRCLK,
	output pdm_out,
	output [9:0] LEDR,
	input  [9:0] switch,
	// VGA outputs 
	output VGA_HS,
	output VGA_VS,
	output [3:0] VGA_R,
	output [3:0] VGA_G,
	output [3:0] VGA_B
);

	wire new_t;
	wire [17:0] sample_out;
	wire is_locked;
	wire [17:0] vocoded_pcm;


	wire clock_3M, pixel_clk; // 3MHZ clock is actually 3.072 MHz for 48KHz sampling rate

	wire [17:0] t0,  t1,  t2,  t3,  t4,  t5,  t6,  t7, t8,  t9,  t10, t11, t12, t13, t14, t15;
	wire [23:0] f0,  f1,  f2,  f3,  f4,  f5,  f6,  f7, f8,  f9,  f10, f11, f12, f13, f14, f15;
	wire done;


	pll3 myPll (
		.areset (~reset),
		.inclk0 (CLOCK_50),
		.c0 (clock_3M),      
		.c1 (pixel_clk),   
		.locked (is_locked)
	);

	 mic_translator main_translator (
		.clk (CLOCK_50),
		.reset(reset),
		.DOUT (MIC_SD),
		.LRCLK (MIC_LRCLK),
		.BCLK(MIC_BCLK),
		.new_t(new_t),
		.sample_out(sample_out),
		.is_locked(is_locked),
		.bclk_in(clock_3M),
		.t0 (t0),
		.t1 (t1),
		.t2 (t2),
		.t3 (t3),
		.t4 (t4),
		.t5 (t5),
		.t6 (t6),
		.t7 (t7),
		.t8 (t8),
		.t9 (t9),
		.t10(t10),
		.t11(t11),
		.t12(t12),
		.t13(t13),
		.t14(t14),
		.t15(t15)
	 );

	fft_processor main_processor (
		.clk(clock_3M),
		.reset (reset),
		.new_t (new_t),
		.t0 (t0),
		.t1 (t1),
		.t2 (t2),
		.t3 (t3),
		.t4 (t4),
		.t5 (t5),
		.t6 (t6),
		.t7 (t7),
		.t8 (t8),
		.t9 (t9),
		.t10(t10),
		.t11(t11),
		.t12(t12),
		.t13(t13),
		.t14(t14),
		.t15(t15),
		.f0 (f0),
		.f1 (f1),
		.f2 (f2),
		.f3 (f3),
		.f4 (f4),
		.f5 (f5),
		.f6 (f6),
		.f7 (f7),
		.f8 (f8),
		.f9 (f9),
		.f10(f10),
		.f11(f11),
		.f12(f12),
		.f13(f13),
		.f14(f14),
		.f15(f15),
		.done(done)
	);


	visualizer vis (
		.pixel_clk (pixel_clk), // 25.175 MHz. standard for 640 x 480 VGA monitors
		.reset (reset),
		.VGA_R (VGA_R),
		.VGA_G(VGA_G),
		.VGA_B (VGA_B),
		.VGA_HS (VGA_HS),
		.VGA_VS (VGA_VS),
		.done(done),
		.f0 (f0),
		.f1 (f1),
		.f2 (f2),
		.f3 (f3),
		.f4 (f4),
		.f5 (f5),   
		.f6 (f6),   
		.f7 (f7),
		.f8 (f8),
		.f9 (f9),   
		.f10(f10),
		.f11(f11),
		.f12(f12),
		.f13(f13),
		.f14(f14),
		.f15(f15)
	);
	 
	 
    speech_vocoder vocoder (
		.clk (clock_3M),
		.reset (reset),
		.pcm_in (sample_out),
		.pcm_valid(new_t),
		.pitch_sel(switch[9:7]),
		.pcm_out(vocoded_pcm)
	);

	// switch vocoder or passthrough mode
	wire [17:0] pcm_selected = switch[0] ? (vocoded_pcm ) : (sample_out << 2);

	pcm_to_pdm PCMtoPDM_converter (
		.clk(clock_3M),
		.reset(~reset),
		.pcm_in(pcm_selected),
		.pdm_out(pdm_out)
	);

endmodule