`define NUM_FRAME_BITS 63   // 64 clocks per full WS period (32 per half)
`define NUM_SAMPLE_BITS 18

module mic_translator(
    input  clk,
    input  reset,
    input  DOUT,
    output LRCLK,
    output BCLK,
    output new_t,
    output reg [17:0] sample_out,
    input  bclk_in,
    input  is_locked
);
    reg lrclk_reg = 1;
    reg [5:0] bit_counter = 0;
    reg [4:0] sample_count = 0;
    reg [17:0] data_buffer = 0;
    reg new_sample_flag = 0;

    assign LRCLK = lrclk_reg;
    assign BCLK  = bclk_in;
    assign new_t = new_sample_flag;
	 


    // WS toggles every 32 BCLK falling edges (full frame = 64 clocks)
    always @(negedge bclk_in) begin
        if (~reset) begin
            lrclk_reg   <= 1;
            bit_counter <= 0;
        end else if (is_locked) begin
            if (bit_counter < `NUM_FRAME_BITS) begin
                bit_counter <= bit_counter + 1;
            end else begin
                lrclk_reg   <= ~lrclk_reg;
                bit_counter <= 0;
            end
        end
    end

    // Capture data on posedge BCLK when WS=HIGH (SEL=HIGH -> right/mono channel)
    // Frame: [bit 0 = delay/skip][bits 1-18 = data MSB first][bits 19-31 = ignore]
    always @(posedge bclk_in) begin
        if (~reset) begin
            sample_count    <= 0;
            data_buffer     <= 0;
            new_sample_flag <= 0;
            sample_out      <= 0;
				
        end else if (is_locked) begin
            if (lrclk_reg == 1) begin
                new_sample_flag <= 0;

                // bit_counter counts within the full 64-clock frame.
                // WS goes high at bit_counter=0. Bit 0 is the delay bit (skip).
                // Bits 1..18 are our 18-bit sample, MSB first.
                // bit_counter runs 32..63 during WS=HIGH half
                if (bit_counter >= 33 && bit_counter <= 50) begin
                    // bit_counter 33 = first data bit (MSB), 50 = LSB
                    data_buffer <= {data_buffer[16:0], DOUT};

                    if (bit_counter == 50) begin
                        sample_out      <= {data_buffer[16:0], DOUT};
                        new_sample_flag <= 1;
                    end
                end
            end else begin
                new_sample_flag <= 0;
            end
        end
    end

endmodule