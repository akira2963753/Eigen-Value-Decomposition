/******************************************************************************
* Copyright (C) 2026 Marco & Innis
*
* File Name:    QRD.sv
* Project:      [Final Project] 2026 Spring DSP In VLSI @NTU <ICDA5003>
* Module:       QRD
* Author:       Marco <harry2963753@gmail.com>
* Student ID:   M11407439 & B11107027
* Tool:         VCS & Verdi
*
******************************************************************************/
`include "define.vh" 

module QRD(
    input clk,
    input rst_n,
    input signed [`DATA_WIDTH-1:0] IN [0:`MATRIX_SIZE-1];
    output logic signed [`DATA_WIDTH-1:0] OUT [0:`MATRIX_SIZE-1]
    );

    logic signed [`DATA_WIDTH-1:0] InX [0:`MATRIX_SIZE*`MATRIX_SIZE-1];
    logic signed [`DATA_WIDHT-1:0] InY [0:`MATRIX_SIZE*`MATRIX_SIZE-1];
    logic signed [`DATA_WIDTH-1:0] OutX [0:`MATRIX_SIZE*`MATRIX_SIZE-1];
    logic signed [`DATA_WIDTH-1:0] OutX [0:`MATRIX_SIZE*`MATRIX_SIZE-1];

    // Fixed 3 x 3 QR-Based Systolic Array
    Delay_Unit R0C0(
        .clk(clk),
        .rst_n(rst_n),
        .IN(),
        .OUT()
    );

endmodule

module Delay_Unit(
    input clk,
    input rst_n,
    input signed [`DATA_WIDTH-1:0] IN,
    output logic signed [`DATA_WIDHT-1:0] OUT
    );
    
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) OUT <= 0;
        else OUT <= IN; 
    end

endmodule