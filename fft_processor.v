// twiddle factors precomputed: exp[-2*pi*i*k/N]
`define twiddle0 48'h7fffff_000000 // 0 deg
`define twiddle1 48'h7641b3_cf043e // -22.5 deg
`define twiddle2 48'h5a827a_a57d86 // -45 deg
`define twiddle3 48'h30fbc2_89be4d // -67.5 deg
`define twiddle4 48'h000000_800000 // -90 deg
`define twiddle5 48'hcf043e_89be4d // -112.5 deg
`define twiddle6 48'ha57d86_a57d86 // -135 deg
`define twiddle7 48'h89be4d_cf043e // -157.5 deg

// 16 point FFT processor using 8 parallel butterfly units
// 4 stages of Cooley-Tukey FFT algorithm --> https://en.wikipedia.org/wiki/Cooley%E2%80%93Tukey_FFT_algorithm
// inputs are 18 bit time based samples from mems mic
// outputs are 24 bit frequency bins 
// 'done' pulses high when results are valid
module fft_processor(
    input clk, input reset, input new_t,
    input [17:0] t0,  input [17:0] t1,  input [17:0] t2,  input [17:0] t3,
    input [17:0] t4,  input [17:0] t5,  input [17:0] t6,  input [17:0] t7,
    input [17:0] t8,  input [17:0] t9,  input [17:0] t10, input [17:0] t11,
    input [17:0] t12, input [17:0] t13, input [17:0] t14, input [17:0] t15,
    output [23:0] f0,  output [23:0] f1,  output [23:0] f2,  output [23:0] f3,
    output [23:0] f4,  output [23:0] f5,  output [23:0] f6,  output [23:0] f7,
    output [23:0] f8,  output [23:0] f9,  output [23:0] f10, output [23:0] f11,
    output [23:0] f12, output [23:0] f13, output [23:0] f14, output [23:0] f15,
    output done
);

    // FSM state encoding
    // waaiting for new_t pulse
    // four butterfly passes of the FFT
    localparam IDLE   = 3'd4;
    localparam STAGE0 = 3'd0;
    localparam STAGE1 = 3'd1;
    localparam STAGE2 = 3'd2;
    localparam STAGE3 = 3'd3;

    reg [2:0] state;

    // done is a single-cycle pulse, default 0, set to 1 only in STAGE3
    reg done_reg;

    reg [47:0] W0, W1, W2, W3, W4, W5, W6, W7;

    reg [47:0] mem0,  mem1,  mem2,  mem3, mem4,  mem5,  mem6,  mem7, mem8,  mem9,  mem10, mem11, mem12, mem13, mem14, mem15;


    wire [47:0] BFU_out0,  BFU_out1,  BFU_out2,  BFU_out3,BFU_out4,  BFU_out5,  BFU_out6,  BFU_out7,BFU_out8,  BFU_out9,  BFU_out10, BFU_out11,BFU_out12, BFU_out13, BFU_out14, BFU_out15;

    // loadd the ssamples in reverse order so that they come out in a natural order after the algo.
    task load_samples;
        begin
            mem0  <= { {6{t0[17]}},  t0,  24'b0};
            mem1  <= { {6{t8[17]}},  t8,  24'b0};
            mem2  <= { {6{t4[17]}},  t4,  24'b0};
            mem3  <= { {6{t12[17]}}, t12, 24'b0};
            mem4  <= { {6{t2[17]}},  t2,  24'b0};
            mem5  <= { {6{t10[17]}}, t10, 24'b0};
            mem6  <= { {6{t6[17]}},  t6,  24'b0};
            mem7  <= { {6{t14[17]}}, t14, 24'b0};
            mem8  <= { {6{t1[17]}},  t1,  24'b0};
            mem9  <= { {6{t9[17]}},  t9,  24'b0};
            mem10 <= { {6{t5[17]}},  t5,  24'b0};
            mem11 <= { {6{t13[17]}}, t13, 24'b0};
            mem12 <= { {6{t3[17]}},  t3,  24'b0};
            mem13 <= { {6{t11[17]}}, t11, 24'b0};
            mem14 <= { {6{t7[17]}},  t7,  24'b0};
            mem15 <= { {6{t15[17]}}, t15, 24'b0};
        end
    endtask

    always @(posedge clk) begin
        done_reg <= 0; // done is low, only pulses high for one cycle

        if (!reset) begin
            state <= IDLE;
            W0 <= 48'b0; W1 <= 48'b0; W2 <= 48'b0; W3 <= 48'b0;
            W4 <= 48'b0; W5 <= 48'b0; W6 <= 48'b0; W7 <= 48'b0;
            // so the display isn't blank at startup
            mem0  <= {24'd1000,  24'b0}; mem1  <= {24'd3000,  24'b0};
            mem2  <= {24'd5000,  24'b0}; mem3  <= {24'd7000,  24'b0};
            mem4  <= {24'd9000,  24'b0}; mem5  <= {24'd11000, 24'b0};
            mem6  <= {24'd13000, 24'b0}; mem7  <= {24'd15000, 24'b0};
            mem8  <= {24'd17000, 24'b0}; mem9  <= {24'd19000, 24'b0};
            mem10 <= {24'd21000, 24'b0}; mem11 <= {24'd23000, 24'b0};
            mem12 <= {24'd25000, 24'b0}; mem13 <= {24'd27000, 24'b0};
            mem14 <= {24'd29000, 24'b0}; mem15 <= {24'd31000, 24'b0};
        end
        else begin
            case (state)

                // wait for mic_translator to signal a new batch of 16 samples
                IDLE: begin
                    if (new_t) begin
                        load_samples;
                        // stage 0 uses W=twiddle0 (1+0j) for all butterfly units
                        W0 <= `twiddle0; W1 <= `twiddle0;
                        W2 <= `twiddle0; W3 <= `twiddle0;
                        W4 <= `twiddle0; W5 <= `twiddle0;
                        W6 <= `twiddle0; W7 <= `twiddle0;
                        state <= STAGE0;
                    end
                end

                // FFT Stage 0: radix-2 butterfly pass, stride 1
                // All twiddle factors are W^0 = 1, so this is just additions/subtractions
                STAGE0: begin
                    mem0  <= BFU_out0;  mem1  <= BFU_out2;
                    mem2  <= BFU_out1;  mem3  <= BFU_out3;
                    mem4  <= BFU_out4;  mem5  <= BFU_out6;
                    mem6  <= BFU_out5;  mem7  <= BFU_out7;
                    mem8  <= BFU_out8;  mem9  <= BFU_out10;
                    mem10 <= BFU_out9;  mem11 <= BFU_out11;
                    mem12 <= BFU_out12; mem13 <= BFU_out14;
                    mem14 <= BFU_out13; mem15 <= BFU_out15;
                    // Stage 1 twiddles: alternating W^0 and W^4 (-j)
                    W0 <= `twiddle0; W1 <= `twiddle4;
                    W2 <= `twiddle0; W3 <= `twiddle4;
                    W4 <= `twiddle0; W5 <= `twiddle4;
                    W6 <= `twiddle0; W7 <= `twiddle4;
                    state <= STAGE1;
                end

                // FFT stage 1: radix 2 butterfly pass, stride 2
                STAGE1: begin
                    mem0  <= BFU_out0;  mem1  <= BFU_out4;
                    mem2  <= BFU_out2;  mem3  <= BFU_out6;
                    mem4  <= BFU_out1;  mem5  <= BFU_out5;
                    mem6  <= BFU_out3;  mem7  <= BFU_out7;
                    mem8  <= BFU_out8;  mem9  <= BFU_out12;
                    mem10 <= BFU_out10; mem11 <= BFU_out14;
                    mem12 <= BFU_out9;  mem13 <= BFU_out13;
                    mem14 <= BFU_out11; mem15 <= BFU_out15;
                    // stage 2 twiddles: W^0, W^2, W^4, W^6
                    W0 <= `twiddle0; W1 <= `twiddle2;
                    W2 <= `twiddle4; W3 <= `twiddle6;
                    W4 <= `twiddle0; W5 <= `twiddle2;
                    W6 <= `twiddle4; W7 <= `twiddle6;
                    state <= STAGE2;
                end

                // FFT stage 2: radix2 butterfly pass, stride 4
                STAGE2: begin
                    mem0  <= BFU_out0;  mem1  <= BFU_out8;
                    mem2  <= BFU_out2;  mem3  <= BFU_out10;
                    mem4  <= BFU_out4;  mem5  <= BFU_out12;
                    mem6  <= BFU_out6;  mem7  <= BFU_out14;
                    mem8  <= BFU_out1;  mem9  <= BFU_out9;
                    mem10 <= BFU_out3;  mem11 <= BFU_out11;
                    mem12 <= BFU_out5;  mem13 <= BFU_out13;
                    mem14 <= BFU_out7;  mem15 <= BFU_out15;
                    // stage 3 twiddles: full set W^0 through W^7
                    W0 <= `twiddle0; W1 <= `twiddle1;
                    W2 <= `twiddle2; W3 <= `twiddle3;
                    W4 <= `twiddle4; W5 <= `twiddle5;
                    W6 <= `twiddle6; W7 <= `twiddle7;
                    state <= STAGE3;
                end

                // FFT stage 3: final butterfly pass, stride 8
         
                STAGE3: begin
                    mem0  <= BFU_out0;  mem1  <= BFU_out2;
                    mem2  <= BFU_out4;  mem3  <= BFU_out6;
                    mem4  <= BFU_out8;  mem5  <= BFU_out10;
                    mem6  <= BFU_out12; mem7  <= BFU_out14;
                    mem8  <= BFU_out1;  mem9  <= BFU_out3;
                    mem10 <= BFU_out5;  mem11 <= BFU_out7;
                    mem12 <= BFU_out9;  mem13 <= BFU_out11;
                    mem14 <= BFU_out13; mem15 <= BFU_out15;
                    done_reg <= 1; // single cycle done pulse for visualizier
                    state <= IDLE;
                end

            endcase
        end
    end

    assign done = done_reg;

    // output upper 24 bits of each memory cell (the real part/magnitude)
    assign f0  = mem0[47:24];  assign f1  = mem1[47:24];
    assign f2  = mem2[47:24];  assign f3  = mem3[47:24];
    assign f4  = mem4[47:24];  assign f5  = mem5[47:24];
    assign f6  = mem6[47:24];  assign f7  = mem7[47:24];
    assign f8  = mem8[47:24];  assign f9  = mem9[47:24];
    assign f10 = mem10[47:24]; assign f11 = mem11[47:24];
    assign f12 = mem12[47:24]; assign f13 = mem13[47:24];
    assign f14 = mem14[47:24]; assign f15 = mem15[47:24];

    // 8 parallel butterfly units, each takes two complex inputs A, B and twiddle W, outputs A+W*B and A-W*B
    butterflyunit BFU0(.A_t(mem0),  .B_t(mem1),  .W(W0), .A_f(BFU_out0),  .B_f(BFU_out1));
    butterflyunit BFU1(.A_t(mem2),  .B_t(mem3),  .W(W1), .A_f(BFU_out2),  .B_f(BFU_out3));
    butterflyunit BFU2(.A_t(mem4),  .B_t(mem5),  .W(W2), .A_f(BFU_out4),  .B_f(BFU_out5));
    butterflyunit BFU3(.A_t(mem6),  .B_t(mem7),  .W(W3), .A_f(BFU_out6),  .B_f(BFU_out7));
    butterflyunit BFU4(.A_t(mem8),  .B_t(mem9),  .W(W4), .A_f(BFU_out8),  .B_f(BFU_out9));
    butterflyunit BFU5(.A_t(mem10), .B_t(mem11), .W(W5), .A_f(BFU_out10), .B_f(BFU_out11));
    butterflyunit BFU6(.A_t(mem12), .B_t(mem13), .W(W6), .A_f(BFU_out12), .B_f(BFU_out13));
    butterflyunit BFU7(.A_t(mem14), .B_t(mem15), .W(W7), .A_f(BFU_out14), .B_f(BFU_out15));

endmodule