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
    input  is_locked,
    // 16 tap parallel outputs (t0 = oldest, t15 = newest)
    output [17:0] t0,  t1,  t2,  t3,
    output [17:0] t4,  t5,  t6,  t7,
    output [17:0] t8,  t9,  t10, t11,
    output [17:0] t12, t13, t14, t15
);

    reg lrclk_reg    = 1;
    reg [5:0] bit_counter = 0;
    reg [17:0] data_buffer = 0;
    reg new_sample_flag = 0;

    // 16 shift register — t0 = oldest sample, t15 = newest
    reg [17:0] tap [0:15];
    integer i;

    assign LRCLK = lrclk_reg;
    assign BCLK  = bclk_in;
    assign new_t = new_sample_flag;

    assign t0  = tap[0];   assign t1  = tap[1];   assign t2  = tap[2];   assign t3  = tap[3];
    assign t4  = tap[4];   assign t5  = tap[5];   assign t6  = tap[6];   assign t7  = tap[7];
    assign t8  = tap[8];   assign t9  = tap[9];   assign t10 = tap[10];  assign t11 = tap[11];
    assign t12 = tap[12];  assign t13 = tap[13];  assign t14 = tap[14];  assign t15 = tap[15];


    always @(negedge bclk_in) begin
        if (~reset) begin
            lrclk_reg   <= 1;
            bit_counter <= 0;
        end else if (is_locked) begin
            if (bit_counter < `NUM_FRAME_BITS)
                bit_counter <= bit_counter + 1;
            else begin
                lrclk_reg   <= ~lrclk_reg;
                bit_counter <= 0;
            end
        end
    end

    always @(posedge bclk_in) begin
        if (~reset) begin
            data_buffer     <= 0;
            new_sample_flag <= 0;
            sample_out      <= 0;
            for (i = 0; i < 16; i = i + 1)
                tap[i] <= 0;
        end else if (is_locked) begin
            if (lrclk_reg == 1) begin
                new_sample_flag <= 0;

                // bit_counter 33 = MSB of sample, 50 = LSB
                if (bit_counter >= 33 && bit_counter <= 50) begin
                    data_buffer <= {data_buffer[16:0], DOUT};

                    if (bit_counter == 50) begin
                        sample_out      <= {data_buffer[16:0], DOUT};
                        new_sample_flag <= 1;

                        // shift all taps, insert new sample at t15
                        for (i = 0; i < 15; i = i + 1)
                            tap[i] <= tap[i + 1];
                        tap[15] <= {data_buffer[16:0], DOUT};
                    end
                end

            end else begin
                new_sample_flag <= 0;
            end
        end
    end

endmodule