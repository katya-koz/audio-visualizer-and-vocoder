module speech_vocoder (
    input  wire        clk,
    input  wire        reset,
    input  wire [17:0] pcm_in,
    input  wire        pcm_valid,
    input  wire [2:0]  pitch_sel,
    output reg  [17:0] pcm_out
);

 // DC BLOCKING FILTER
 reg signed [17:0] pcm_prev;
 reg signed [17:0] hp_out;

 always @(posedge clk) begin
	  if (~reset) begin
			pcm_prev <= 0;
			hp_out   <= 0;
	  end else if (pcm_valid) begin
			pcm_prev <= pcm_in;
			hp_out   <= $signed(pcm_in)  - $signed(pcm_prev)
						 + $signed(hp_out)  - $signed(hp_out >>> 10);
	  end
 end

 //NOISE GATE 
 reg [17:0] envelope;
 wire [17:0] abs_hp = hp_out[17] ? (~hp_out + 1'b1) : hp_out;

 always @(posedge clk) begin
	  if (~reset) begin
			envelope <= 0;
	  end else if (pcm_valid) begin
			if (abs_hp > envelope)
				 envelope <= envelope + ((abs_hp - envelope) >> 3);
			else
				 envelope <= envelope - ((envelope - abs_hp) >> 8);
	  end
 end

 localparam [17:0] GATE_THRESH = 18'd900;
 wire gate_open = (envelope > GATE_THRESH);

//SINE LOOK UP TABLE CARRIER —-> 256 entries, 18 bit signed
//phase accumulator: 24-bit (8 integer + 16 fractional)
//LUT index = phase_acc[23:16]

//phase_inc = freq * 256 * 65536 / 62500
//400  Hz -> 106954
//600  Hz -> 160431
//800  Hz -> 213909
//1200 Hz -> 320863
//1800 Hz -> 481294

 reg [23:0] phase_acc;
 reg [23:0] phase_inc;

 always @(*) begin
			case (pitch_sel)
	 3'd0: phase_inc = 24'd26738;  // 100 Hz
	  3'd1: phase_inc = 24'd53477;  // 200 Hz
	  3'd2: phase_inc = 24'd80215;  // 300 Hz
	  3'd3: phase_inc = 24'd106954; // 400 Hz
	  3'd4: phase_inc = 24'd160431; // 600 Hz
	  3'd5: phase_inc = 24'd213909; // 800 Hz
	  3'd6: phase_inc = 24'd320863; // 1200 Hz
	  3'd7: phase_inc = 24'd481294;// 1800 Hz
	  default: phase_inc = 24'd160431;
 endcase
 end

 always @(posedge clk) begin
	  if (~reset)
			phase_acc <= 0;
	  else if (pcm_valid)
			phase_acc <= phase_acc + phase_inc;
 end

 wire [7:0] lut_index = phase_acc[23:16];

 reg signed [17:0] sine_lut [0:255];
 initial begin
 // generated with python script
	  sine_lut[0]   = 18'sd0;        sine_lut[1]   = 18'sd3217;
	  sine_lut[2]   = 18'sd6431;     sine_lut[3]   = 18'sd9642;
	  sine_lut[4]   = 18'sd12847;    sine_lut[5]   = 18'sd16044;
	  sine_lut[6]   = 18'sd19232;    sine_lut[7]   = 18'sd22408;
	  sine_lut[8]   = 18'sd25571;    sine_lut[9]   = 18'sd28718;
	  sine_lut[10]  = 18'sd31848;    sine_lut[11]  = 18'sd34958;
	  sine_lut[12]  = 18'sd38048;    sine_lut[13]  = 18'sd41115;
	  sine_lut[14]  = 18'sd44156;    sine_lut[15]  = 18'sd47172;
	  sine_lut[16]  = 18'sd50159;    sine_lut[17]  = 18'sd53115;
	  sine_lut[18]  = 18'sd56040;    sine_lut[19]  = 18'sd58931;
	  sine_lut[20]  = 18'sd61786;    sine_lut[21]  = 18'sd64605;
	  sine_lut[22]  = 18'sd67384;    sine_lut[23]  = 18'sd70123;
	  sine_lut[24]  = 18'sd72819;    sine_lut[25]  = 18'sd75472;
	  sine_lut[26]  = 18'sd78079;    sine_lut[27]  = 18'sd80639;
	  sine_lut[28]  = 18'sd83151;    sine_lut[29]  = 18'sd85612;
	  sine_lut[30]  = 18'sd88022;    sine_lut[31]  = 18'sd90379;
	  sine_lut[32]  = 18'sd92681;    sine_lut[33]  = 18'sd94928;
	  sine_lut[34]  = 18'sd97117;    sine_lut[35]  = 18'sd99248;
	  sine_lut[36]  = 18'sd101319;   sine_lut[37]  = 18'sd103329;
	  sine_lut[38]  = 18'sd105277;   sine_lut[39]  = 18'sd107162;
	  sine_lut[40]  = 18'sd108982;   sine_lut[41]  = 18'sd110736;
	  sine_lut[42]  = 18'sd112423;   sine_lut[43]  = 18'sd114043;
	  sine_lut[44]  = 18'sd115594;   sine_lut[45]  = 18'sd117076;
	  sine_lut[46]  = 18'sd118487;   sine_lut[47]  = 18'sd119826;
	  sine_lut[48]  = 18'sd121094;   sine_lut[49]  = 18'sd122288;
	  sine_lut[50]  = 18'sd123409;   sine_lut[51]  = 18'sd124456;
	  sine_lut[52]  = 18'sd125427;   sine_lut[53]  = 18'sd126323;
	  sine_lut[54]  = 18'sd127143;   sine_lut[55]  = 18'sd127886;
	  sine_lut[56]  = 18'sd128553;   sine_lut[57]  = 18'sd129141;
	  sine_lut[58]  = 18'sd129652;   sine_lut[59]  = 18'sd130085;
	  sine_lut[60]  = 18'sd130440;   sine_lut[61]  = 18'sd130716;
	  sine_lut[62]  = 18'sd130913;   sine_lut[63]  = 18'sd131032;
	  sine_lut[64]  = 18'sd131071;   sine_lut[65]  = 18'sd131032;
	  sine_lut[66]  = 18'sd130913;   sine_lut[67]  = 18'sd130716;
	  sine_lut[68]  = 18'sd130440;   sine_lut[69]  = 18'sd130085;
	  sine_lut[70]  = 18'sd129652;   sine_lut[71]  = 18'sd129141;
	  sine_lut[72]  = 18'sd128553;   sine_lut[73]  = 18'sd127886;
	  sine_lut[74]  = 18'sd127143;   sine_lut[75]  = 18'sd126323;
	  sine_lut[76]  = 18'sd125427;   sine_lut[77]  = 18'sd124456;
	  sine_lut[78]  = 18'sd123409;   sine_lut[79]  = 18'sd122288;
	  sine_lut[80]  = 18'sd121094;   sine_lut[81]  = 18'sd119826;
	  sine_lut[82]  = 18'sd118487;   sine_lut[83]  = 18'sd117076;
	  sine_lut[84]  = 18'sd115594;   sine_lut[85]  = 18'sd114043;
	  sine_lut[86]  = 18'sd112423;   sine_lut[87]  = 18'sd110736;
	  sine_lut[88]  = 18'sd108982;   sine_lut[89]  = 18'sd107162;
	  sine_lut[90]  = 18'sd105277;   sine_lut[91]  = 18'sd103329;
	  sine_lut[92]  = 18'sd101319;   sine_lut[93]  = 18'sd99248;
	  sine_lut[94]  = 18'sd97117;    sine_lut[95]  = 18'sd94928;
	  sine_lut[96]  = 18'sd92681;    sine_lut[97]  = 18'sd90379;
	  sine_lut[98]  = 18'sd88022;    sine_lut[99]  = 18'sd85612;
	  sine_lut[100] = 18'sd83151;    sine_lut[101] = 18'sd80639;
	  sine_lut[102] = 18'sd78079;    sine_lut[103] = 18'sd75472;
	  sine_lut[104] = 18'sd72819;    sine_lut[105] = 18'sd70123;
	  sine_lut[106] = 18'sd67384;    sine_lut[107] = 18'sd64605;
	  sine_lut[108] = 18'sd61786;    sine_lut[109] = 18'sd58931;
	  sine_lut[110] = 18'sd56040;    sine_lut[111] = 18'sd53115;
	  sine_lut[112] = 18'sd50159;    sine_lut[113] = 18'sd47172;
	  sine_lut[114] = 18'sd44156;    sine_lut[115] = 18'sd41115;
	  sine_lut[116] = 18'sd38048;    sine_lut[117] = 18'sd34958;
	  sine_lut[118] = 18'sd31848;    sine_lut[119] = 18'sd28718;
	  sine_lut[120] = 18'sd25571;    sine_lut[121] = 18'sd22408;
	  sine_lut[122] = 18'sd19232;    sine_lut[123] = 18'sd16044;
	  sine_lut[124] = 18'sd12847;    sine_lut[125] = 18'sd9642;
	  sine_lut[126] = 18'sd6431;     sine_lut[127] = 18'sd3217;
	  sine_lut[128] = 18'sd0;        sine_lut[129] = -18'sd3217;
	  sine_lut[130] = -18'sd6431;    sine_lut[131] = -18'sd9642;
	  sine_lut[132] = -18'sd12847;   sine_lut[133] = -18'sd16044;
	  sine_lut[134] = -18'sd19232;   sine_lut[135] = -18'sd22408;
	  sine_lut[136] = -18'sd25571;   sine_lut[137] = -18'sd28718;
	  sine_lut[138] = -18'sd31848;   sine_lut[139] = -18'sd34958;
	  sine_lut[140] = -18'sd38048;   sine_lut[141] = -18'sd41115;
	  sine_lut[142] = -18'sd44156;   sine_lut[143] = -18'sd47172;
	  sine_lut[144] = -18'sd50159;   sine_lut[145] = -18'sd53115;
	  sine_lut[146] = -18'sd56040;   sine_lut[147] = -18'sd58931;
	  sine_lut[148] = -18'sd61786;   sine_lut[149] = -18'sd64605;
	  sine_lut[150] = -18'sd67384;   sine_lut[151] = -18'sd70123;
	  sine_lut[152] = -18'sd72819;   sine_lut[153] = -18'sd75472;
	  sine_lut[154] = -18'sd78079;   sine_lut[155] = -18'sd80639;
	  sine_lut[156] = -18'sd83151;   sine_lut[157] = -18'sd85612;
	  sine_lut[158] = -18'sd88022;   sine_lut[159] = -18'sd90379;
	  sine_lut[160] = -18'sd92681;   sine_lut[161] = -18'sd94928;
	  sine_lut[162] = -18'sd97117;   sine_lut[163] = -18'sd99248;
	  sine_lut[164] = -18'sd101319;  sine_lut[165] = -18'sd103329;
	  sine_lut[166] = -18'sd105277;  sine_lut[167] = -18'sd107162;
	  sine_lut[168] = -18'sd108982;  sine_lut[169] = -18'sd110736;
	  sine_lut[170] = -18'sd112423;  sine_lut[171] = -18'sd114043;
	  sine_lut[172] = -18'sd115594;  sine_lut[173] = -18'sd117076;
	  sine_lut[174] = -18'sd118487;  sine_lut[175] = -18'sd119826;
	  sine_lut[176] = -18'sd121094;  sine_lut[177] = -18'sd122288;
	  sine_lut[178] = -18'sd123409;  sine_lut[179] = -18'sd124456;
	  sine_lut[180] = -18'sd125427;  sine_lut[181] = -18'sd126323;
	  sine_lut[182] = -18'sd127143;  sine_lut[183] = -18'sd127886;
	  sine_lut[184] = -18'sd128553;  sine_lut[185] = -18'sd129141;
	  sine_lut[186] = -18'sd129652;  sine_lut[187] = -18'sd130085;
	  sine_lut[188] = -18'sd130440;  sine_lut[189] = -18'sd130716;
	  sine_lut[190] = -18'sd130913;  sine_lut[191] = -18'sd131032;
	  sine_lut[192] = -18'sd131071;  sine_lut[193] = -18'sd131032;
	  sine_lut[194] = -18'sd130913;  sine_lut[195] = -18'sd130716;
	  sine_lut[196] = -18'sd130440;  sine_lut[197] = -18'sd130085;
	  sine_lut[198] = -18'sd129652;  sine_lut[199] = -18'sd129141;
	  sine_lut[200] = -18'sd128553;  sine_lut[201] = -18'sd127886;
	  sine_lut[202] = -18'sd127143;  sine_lut[203] = -18'sd126323;
	  sine_lut[204] = -18'sd125427;  sine_lut[205] = -18'sd124456;
	  sine_lut[206] = -18'sd123409;  sine_lut[207] = -18'sd122288;
	  sine_lut[208] = -18'sd121094;  sine_lut[209] = -18'sd119826;
	  sine_lut[210] = -18'sd118487;  sine_lut[211] = -18'sd117076;
	  sine_lut[212] = -18'sd115594;  sine_lut[213] = -18'sd114043;
	  sine_lut[214] = -18'sd112423;  sine_lut[215] = -18'sd110736;
	  sine_lut[216] = -18'sd108982;  sine_lut[217] = -18'sd107162;
	  sine_lut[218] = -18'sd105277;  sine_lut[219] = -18'sd103329;
	  sine_lut[220] = -18'sd101319;  sine_lut[221] = -18'sd99248;
	  sine_lut[222] = -18'sd97117;   sine_lut[223] = -18'sd94928;
	  sine_lut[224] = -18'sd92681;   sine_lut[225] = -18'sd90379;
	  sine_lut[226] = -18'sd88022;   sine_lut[227] = -18'sd85612;
	  sine_lut[228] = -18'sd83151;   sine_lut[229] = -18'sd80639;
	  sine_lut[230] = -18'sd78079;   sine_lut[231] = -18'sd75472;
	  sine_lut[232] = -18'sd72819;   sine_lut[233] = -18'sd70123;
	  sine_lut[234] = -18'sd67384;   sine_lut[235] = -18'sd64605;
	  sine_lut[236] = -18'sd61786;   sine_lut[237] = -18'sd58931;
	  sine_lut[238] = -18'sd56040;   sine_lut[239] = -18'sd53115;
	  sine_lut[240] = -18'sd50159;   sine_lut[241] = -18'sd47172;
	  sine_lut[242] = -18'sd44156;   sine_lut[243] = -18'sd41115;
	  sine_lut[244] = -18'sd38048;   sine_lut[245] = -18'sd34958;
	  sine_lut[246] = -18'sd31848;   sine_lut[247] = -18'sd28718;
	  sine_lut[248] = -18'sd25571;   sine_lut[249] = -18'sd22408;
	  sine_lut[250] = -18'sd19232;   sine_lut[251] = -18'sd16044;
	  sine_lut[252] = -18'sd12847;   sine_lut[253] = -18'sd9642;
	  sine_lut[254] = -18'sd6431;    sine_lut[255] = -18'sd3217;
 end

 wire signed [17:0] carrier  = sine_lut[lut_index];

 // RING MODULATION
 //product = hp_out * carrier
 
 wire signed [17:0] hp_attenuated = $signed(hp_out) >>> 4; // reduce by 16x to prevent overflow

 
 wire signed [35:0] product  = $signed(hp_attenuated) * $signed(carrier);
 wire signed [17:0] ring_out = product[34:17];

 always @(posedge clk) begin
	  if (~reset)
			pcm_out <= 0;
	  else if (pcm_valid)
			pcm_out <= gate_open ? ring_out : 18'd0;
 end

endmodule