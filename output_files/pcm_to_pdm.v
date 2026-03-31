module pcm_to_pdm 
#(parameter WIDTH = 18)
(
    input wire clk,        // PDM clock  (4 MHz for x64 OSR)
    input wire reset,
    input wire signed [WIDTH-1:0] pcm_in, // 16-bit PCM sample
    output reg pdm_out,             // 1-bit PDM output
	 input wire pcm_valid
);


// https://www.reddit.com/r/FPGA/comments/zm7vob/how_does_one_choose_a_pwm_period_for/ <- suggestion to use PDM in comments here
// https://tomverbeure.github.io/2020/10/04/PDM-Microphones-and-Sigma-Delta-Conversion.html 
// pdm audio is higher quality and easier to scale than pwm. although, the conversion from pcm (which is the format we get audio in from the MEMs I2S) to pdm is annoying.
// PCM -> PDM conversion steps:
// 1. oversample at a rate x64 (the mems mic datasheet actually uses a decimator with a factor of 64)
// 2. delta sigma modulator to force average pulse density to match input amplitude
// 3. 1 bit quantization - produce a 1 bit stream of 1's and 0's where the density of 1's representss the amplitude of the audio signal

/*
https://en.wikipedia.org/wiki/Pulse-density_modulation -> algorithm to convert PCM to PDM

function pdm(real[0..s] x, real qe = 0) // initial running error is zero
    var int[0..s] y
  
    for n from 0 to s do
        qe := qe + x[n]
        if qe > 0 then
            y[n] := 1
        else
            y[n] := −1
        qe := qe - y[n]
  
    return y, qe // return output and running error
	 
	 
	 https://www.fpga4fun.com/PWM_DAC_2.html

*/


	reg signed [WIDTH:0] acc1 = 0;
	reg signed [WIDTH:0] acc2 = 0;
	reg signed [WIDTH:0] acc3 = 0;
	reg signed [WIDTH:0] acc4 = 0;
    always @(posedge clk) begin
        acc1 <= acc1[WIDTH - 1:0] + pcm_in - pdm_out;
		  acc2 <= acc2[WIDTH - 1:0] + (acc1 >>> 2) ;
		  acc3 <= acc3[WIDTH - 1:0] + (acc2 >>> 2) ;
		  acc4 <= acc4[WIDTH - 1:0] + (acc3 >>> 2);
		  

        pdm_out <= acc1[WIDTH];
        if(reset) begin
            pdm_out <= 0;
            acc1 <= 0;
				acc2 <= 0;
				acc3 <= 0;
				acc4 <= 0;
        end
    end

/
// first order delta sigma modulator, x64 oversampling rate (OSR)

 /*  reg [WIDTH:0] acc1 = 0;
	reg [WIDTH + 1:0] acc2 = 0;
	reg [WIDTH + 2:0] acc3 = 0;
	reg [WIDTH + 3:0] acc4 = 0;
    always @(posedge clk) begin
        acc1 <= acc1[WIDTH - 1 :0] + pcm_in - pdm_out;
		  acc2 <= acc2[WIDTH + 1 - 1:0] + acc1 - pdm_out;
		  acc3 <= acc3[WIDTH + 2 - 1:0] + acc2 - pdm_out;
		  acc4 <= acc4[WIDTH + 3 - 1:0] + acc3 - pdm_out;
		  
        pdm_out <= acc2[WIDTH + 3];
        if(reset) begin
            pdm_out <= 0;
            acc1 <= 0;
				acc2 <= 0;
				acc3 <= 0;
				acc4 <= 0;
        end
    end
	 
	 */
	 
/*	 parameter K1 = 2; // scale for acc1 → acc2
parameter K2 = 2; // acc2 → acc3
parameter K3 = 2; // acc3 → acc4
parameter K4 = 1; // direct feed from acc4 (optional)

reg [WIDTH + 2:0] acc1 = 0;
reg [WIDTH+3:0] acc2 = 0;
reg [WIDTH+4:0] acc3 = 0;
reg [WIDTH+5:0] acc4 = 0;

always @(posedge clk) begin
    if(reset) begin
        pdm_out <= 0;
        acc1 <= 0; acc2 <= 0; acc3 <= 0; acc4 <= 0;
    end else begin
        // First integrator
        acc1 <= acc1[WIDTH + 2-1:0] + pcm_in - pdm_out;

        // Second integrator with coefficient
        acc2 <= acc2[WIDTH+3-1:0] + (K1 * acc1) - pdm_out;

        // Third integrator with coefficient
        acc3 <= acc3[WIDTH+4-1:0] + (K2 * acc2) - pdm_out;

        // Fourth integrator with coefficient
        acc4 <= acc4[WIDTH+5-1:0] + (K3 * acc3) - pdm_out;

        // Output MSB
        pdm_out <= acc4[WIDTH+5];
    end
	 end*/
	 
endmodule

