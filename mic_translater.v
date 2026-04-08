//https://cdn-shop.adafruit.com/product-files/3421/i2S+Datasheet.PDF
`define NUM_FRAME_BITS 31
`define NUM_SAMPLE_BITS 18
`define _CALIBRATION {13'd226, 5'd0}
module mic_translator(input clk, input reset, input DOUT, output LRCLK, output BCLK, output new_t,
                             output[17:0] sample_out, input bclk_in, input is_locked);

    wire bclk_wire,lrclk_wire;
    reg bclk_reg, lrclk_reg;
    reg new_sample_flag;
    assign LRCLK = lrclk_reg;
    assign BCLK = bclk_in;

    assign bclk_wire = bclk_in;

    // pll created from 50MHz clock -> 4MHz clock *according to MEMs datasheet
    /*pll3 myPll (
         .areset   (~reset),
         .inclk0   (clk),         //50 MHz input
         .c0       (bclk_wire),  // 4 MHz output
         .locked   (is_locked)     // stabilitiy check
    );*/

    reg [5:0] bit_counter = 6'b0; // count to 32 for LRCLK
    reg [17:0] data_buffer;
    reg signed [17:0] audio_sample;

    always @(negedge bclk_wire) begin // LRCLK changes on falling edge of clock
        if (~reset) begin
            lrclk_reg <= 1'b1;
            bit_counter <= 5'b0;
        end else 
        if(is_locked) begin 
            if (bit_counter < `NUM_FRAME_BITS) begin
                bit_counter <= bit_counter + 1;
            end
            else begin
                lrclk_reg <= ~lrclk_reg;
                bit_counter <= 6'b0;

            end
        end
    end

    //reg[5:0] data_frame_counter = 6'b0; // count up to 32... then reset
    reg[4:0] sample_count = 1; // 1...18 -> repeat

    always @(posedge bclk_wire) begin // data collected on posedge of clock
    // okay SO. on every WS switch, (either to a rising or falling edge) AKA every 32 bits, data frame begins. 
    // it skips the first frame: [0 - skip frame][1 - 18 DATA (1 is MSB, 18 is LSB][19-24 LOW][25-32 TRI STATE]... repeat

        if(is_locked && lrclk_reg == 1) begin  // collect data only when stable. // when SEL is set HIGH then collect data when lrclk_reg is HIGH
            if(sample_count < `NUM_SAMPLE_BITS) begin // this indicates we are in the threshhold of data collection (1 - 18). skip first frame.
                sample_count <= sample_count + 1;
                data_buffer <= {data_buffer[16:0], DOUT}; // shift frame onto the data buffer

            end else begin // on the 18th sample bit...

                audio_sample <= {data_buffer[16:0], DOUT};
                data_buffer <= 18'b0;
                new_sample_flag <= 1; // sample ready
                sample_count <= 1;

            end
        end else if(lrclk_reg == 0) begin
            new_sample_flag <= 0;

        end
    end    
    assign sample_out = (audio_sample); // 18 bits are the sample. this is the res. of the MEMs mic. calibrated to remove DC offset. + `_CALIBRATION + 18'h20000
    assign lrclk_wire = lrclk_reg;
    assign new_t = new_sample_flag;
    // 4Mhz BCLK cycle, WS / sample ready is 62.5KHz (thats really high for audio)

endmodule