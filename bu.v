// radix 2 Butterfly Unit for 16-point Cooley-Tukey FFT --> https://en.wikipedia.org/wiki/Cooley%E2%80%93Tukey_FFT_algorithm
//  A_f = A_t + W * B_t
//  B_f = A_t - W * B_t

// All values are 48-bit complex fixed-point:
//   bits [47:24] = real part
//   bits [23:0]  = imaginary part

// twiddle factors  are pre scaled by 2^23 to make up for
// the 23 bit truncation applied after multiplication.
module butterflyunit(
	input  [47:0] A_t,  // complex input 
	input  [47:0] B_t,  // complex input 
	input  [47:0] W,    // twiddle factor 
	output [47:0] A_f,  // complex output
	output [47:0] B_f   // complex output
);

    // complex multiplier: compute W * B_t

    wire [47:0] A_real_B_real = {{24{B_t[47]}}, B_t[47:24]} * {{24{W[47]}}, W[47:24]};  // ac  (B_real * W_real)
    wire [47:0] A_imag_B_imag = {{24{B_t[23]}}, B_t[23:0]}  * {{24{W[23]}}, W[23:0]};   // bd  (B_imag * W_imag)
    wire [47:0] A_imag_B_real = {{24{B_t[23]}}, B_t[23:0]}  * {{24{W[47]}}, W[47:24]};  // bc  (B_imag * W_real)
    wire [47:0] A_real_B_imag = {{24{B_t[47]}}, B_t[47:24]} * {{24{W[23]}}, W[23:0]};   // ad  (B_real * W_imag)

    // combine partial products into full 96 bit complex result
    wire [95:0] multout;
    assign multout[95:48] = A_real_B_real - A_imag_B_imag;  // real: ac - bd
    assign multout[47:0]  = A_imag_B_real + A_real_B_imag;  // imag: bc + ad

    
    // reduce 96bit product back to 24 bits per component
    
    // real: bits [94:71]  (skip redundant sign bit 95)
    // imag: bits [46:23]  (skip redundant sign bit 47)
    wire [47:0] truncated_prod = {multout[94:71], multout[46:23]};

   
    // complex Adder:    A_f = A_t + W*B_t
    // complex Subractor B_f = A_t - W*B_t
    // applied separately to real and imaginary parts
    assign A_f[47:24] = A_t[47:24] + truncated_prod[47:24];  // real: A_real + (W*B)_real
    assign A_f[23:0]  = A_t[23:0]  + truncated_prod[23:0];   // imag: A_imag + (W*B)_imag

    assign B_f[47:24] = A_t[47:24] - truncated_prod[47:24];  // real: A_real - (W*B)_real
    assign B_f[23:0]  = A_t[23:0]  - truncated_prod[23:0];   // imag: A_imag - (W*B)_imag

endmodule