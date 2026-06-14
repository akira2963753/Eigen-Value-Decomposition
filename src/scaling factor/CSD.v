// ================================================================================
// Design Name	: CSD
// Function			: Scale signed input with a CSD shift-and-add network
// File Name		: src/scaling factor/CSD.v
// Author				: Michael Su, Sr. Consultant, SiCADA, Taiwan
// Date					: 2026-06-14
// Version			: 1.1
// GenAI				: GPT-5 (OpenAI, 2026-06)
// ================================================================================

module CSD #(
	parameter  DATA_WIDTH = 18,	// Signed input and output width
	parameter  DATA_FRAC = 11	// Fractional bits in input and output data
) (
	input  signed [DATA_WIDTH-1:0] scale_in,	// Signed input with DATA_FRAC fractional bits
	output signed [DATA_WIDTH-1:0] scale_out	// Signed output with DATA_FRAC fractional bits
) ;

	localparam  ACC_WIDTH = DATA_WIDTH + 3 ;	// Guard bits prevent intermediate overflow

	wire signed [ACC_WIDTH-1:0] input_ext ;
	wire signed [ACC_WIDTH-1:0] scaled_sum ;

	assign input_ext = $signed(
		{{(ACC_WIDTH-DATA_WIDTH){scale_in[DATA_WIDTH-1]}}, scale_in}
	) ;

	// Per-term truncation is intentional for the low-area CSD approximation.
	assign scaled_sum = (input_ext >>> 1)
		+ (input_ext >>> 3)
		- (input_ext >>> 6) 
		- (input_ext >>> 9)
		- (input_ext >>> 13)
		- (input_ext >>> 15)
		- (input_ext >>> 17) ;

	assign scale_out = $signed(scaled_sum[DATA_WIDTH-1:0]) ;

endmodule
