// ================================================================================
// Design Name	: direct_mult_scale
// Function			: Scale signed input with a constant multiplier
// File Name		: src/scaling factor/ori.v
// Author				: Michael Su, Sr. Consultant, SiCADA, Taiwan
// Date					: 2026-06-13
// Version			: 1.0
// GenAI				: GPT-5 (OpenAI, 2026-06)
// ================================================================================

module direct_mult_scale #(
	parameter  DATA_WIDTH = 18	// Signed input and output width
) (
	input  signed [DATA_WIDTH-1:0] scale_in,	// Signed value before scaling
	output signed [DATA_WIDTH-1:0] scale_out	// Signed multiplier-scaled value
) ;

	localparam  K_INV_FRAC = 14 ;				// Fractional bits in K inverse
	localparam  K_INV_WIDTH = 14 ;				// Stored width of K inverse
	localparam  PRODUCT_WIDTH = DATA_WIDTH + K_INV_WIDTH ;	// Full product width
	localparam  signed [K_INV_WIDTH-1:0] K_INV = 14'sd9949 ;	// Quantized K inverse

	wire signed [PRODUCT_WIDTH-1:0] product ;

	assign product = scale_in * K_INV ;
	assign scale_out = product[K_INV_FRAC+DATA_WIDTH-1:K_INV_FRAC] ;

endmodule
