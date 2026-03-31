module vocoder (
    input CLOCK_50,
    input MIC_SD,
    input reset,
    output MIC_BCLK,
    output MIC_LRCLK,
    output pwm_out,
    output [9:0] LEDR
);

    // https://cdn-shop.adafruit.com/product-files/3421/i2S+Datasheet.PDF -- mic
    wire new_t;
    wire [17:0] sample_out; // already calibrated and left-shifted in mic_translator
	 wire is_locked, pwm_clk;
	 
	/* pll3 myPll (
		 .areset   (~reset),
		 .inclk0   (CLOCK_50),//50 MHz input
		 .c0 		  (pwm_clk),  // 255MHz clock
		 .c1       (bclk),  // 4 MHz output
		 .locked   (is_locked) 	// stabilitiy check
	);*/
	
	/*pll2 myPll (
		 .areset   (~reset),
		 .inclk0   (CLOCK_50),         //50 MHz input
		 .c0       (clock_4M),  // 4 MHz output
		 .locked   (is_locked) 	// stabilitiy check
	);*/
	
	pll5 myPll (
		 .areset   (~reset),
		 .inclk0   (CLOCK_50),         //50 MHz input
		 .c0       (clock_4M),  // 4 MHz output
		 .c1       (clock_16M),  // 4 MHz output
		 .locked   (is_locked) 	// stabilitiy check
	);

    mic_translator main_translator(
        .clk        (CLOCK_50),
        .reset      (reset),
        .DOUT       (MIC_SD),
        .LRCLK      (MIC_LRCLK),
        .BCLK       (MIC_BCLK),
        .new_t      (new_t),
        .sample_out (sample_out),
		  .is_locked (is_locked),
		  .bclk_in (clock_4M)
    );
	 
	 
	 
	 wire pdm_wire;
	 // the adafruit mems mic im using outputs pcm. i am converting it to pdm to play.
	 // i should only need a 16MHz clock for this
	 pcm_to_pdm PCMtoPDM_converter(
    .clk (clock_4M),                 // high-speed clock (4MHz)
    .reset (~reset),
	 .pcm_in		(sample_out[17:0]), // 16-bit PCM sample
    .pdm_out (pdm_wire), // 1-bit PDM output
	 .pcm_valid (new_t)
	);
	 
	 
	 assign pwm_out = pdm_wire;
	 
	 assign LEDR[7:0] = sample_out[17:10]; // audio amplitude visualization
    assign LEDR[8] = MIC_BCLK;
    assign LEDR[9] = MIC_LRCLK;
	 
	 
	 // nyquist-shannon theorem - signal can be reconstructed 'perfectly' with 80 ns between samples (derived from 62.5kHz sample rate of mic)
	 // clock must be 1/80ns = 125kHz

    /*// --- Synchronize new sample flag to 255MHz system clock ---
    reg new_t_sync1, new_t_sync2;
    always @(posedge pwm_clk) begin
        new_t_sync1 <= new_t;
        new_t_sync2 <= new_t_sync1;
    end

    // --- PWM setup ---
    reg [11:0] pwm_counter = 0;    // 12-bit PWM counter
    reg [11:0] pwm_sample = 0;     // scaled sample for PWM

    always @(posedge pwm_clk) begin
        pwm_counter <= pwm_counter + 1;

        // Capture new sample when available
        if (new_t_sync2) begin
            // Use top 12 bits of 18-bit audio for 12-bit PWM
            pwm_sample <= {sample_out[17:6]};
        end
    end

    assign pwm_out = (pwm_counter < pwm_sample);

    // --- LEDs for debugging ---
	 
	 */
    

endmodule