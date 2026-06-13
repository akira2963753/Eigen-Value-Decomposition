// ================================================================================
// Design Name	: csd_scale
// Function		: Scale signed input with a CSD shift-and-add network
// File Name	: src/scaling factor/CSD.v
// Author		: Michael Su, Sr. Consultant, SiCADA, Taiwan
// Date			: 2026-06-13
// Version		: 1.0
// GenAI		: GPT-5 (OpenAI, 2026-06)
// ================================================================================

module csd_scale #(
	parameter  DATA_WIDTH = 18	// Signed input and output width
) (
	input  signed [DATA_WIDTH-1:0] scale_in,	// Signed value before scaling
	output signed [DATA_WIDTH-1:0] scale_out	// Signed CSD-scaled value
) ;

	localparam  ACC_WIDTH = DATA_WIDTH + 3 ;	// Guard bits prevent intermediate overflow

	wire signed [ACC_WIDTH-1:0] input_ext ;
	wire signed [ACC_WIDTH-1:0] scaled_sum ;

	assign input_ext = {{(ACC_WIDTH-DATA_WIDTH){scale_in[DATA_WIDTH-1]}}, scale_in} ;

	assign scaled_sum = (input_ext >>> 1)
		+ (input_ext >>> 3)
		+ (input_ext >>> 14)
		- (input_ext >>> 6)
		- (input_ext >>> 9)
		- (input_ext >>> 12) ;

	assign scale_out = scaled_sum[DATA_WIDTH-1:0] ;

endmodule
