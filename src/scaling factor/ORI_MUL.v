// ================================================================================
// Design Name	: ORI_MUL
// Function			: Scale signed input with a constant multiplier
// File Name		: src/scaling factor/ORI_MUL.v
// Author				: Michael Su, Sr. Consultant, SiCADA, Taiwan
// Date					: 2026-06-14
// Version			: 1.1
// GenAI				: GPT-5 (OpenAI, 2026-06)
// ================================================================================

module ORI_MUL #(
	parameter  DATA_WIDTH = 18,	// Signed input and output width
	parameter  DATA_FRAC = 11	// Fractional bits in input and output data
) (
	input  signed [DATA_WIDTH-1:0] scale_in,	// Signed input with DATA_FRAC fractional bits
	output signed [DATA_WIDTH-1:0] scale_out	// Signed output with DATA_FRAC fractional bits
) ;

	localparam  K_INV_FRAC = 16 ;				// Fractional bits in K inverse
	localparam  K_INV_WIDTH = 17 ;				// Stored width of signed K inverse
	localparam  PRODUCT_WIDTH = DATA_WIDTH + K_INV_WIDTH ;	// Full product width
	localparam  signed [K_INV_WIDTH-1:0] K_INV = 17'sd39797 ;	// Quantized K inverse

	wire signed [PRODUCT_WIDTH-1:0] product ;

	assign product = scale_in * K_INV ;
	assign scale_out = $signed(product[K_INV_FRAC+DATA_WIDTH-1:K_INV_FRAC]) ;

endmodule
