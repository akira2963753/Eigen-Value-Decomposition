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
    input InMode,
    input signed [`DATA_WIDTH-1:0] InData [0:`MATRIX_SIZE-1],
    output logic signed [`DATA_WIDTH-1:0] OutData [0:`MATRIX_SIZE-1]
    ); 

    // 直接建構 2D Systolic Array，方便後面用 Generate，多出來的 Net 沒 Drive 就會被移除
    logic signed [`DATA_WIDTH-1:0] X_h [0:`MATRIX_SIZE-1][0:`MATRIX_SIZE-1];
    logic signed [`DATA_WIDTH-1:0] Y_v [0:`MATRIX_SIZE-1][0:`MATRIX_SIZE-1];
    logic Mode_r [0:`MATRIX_SIZE-1][0:`MATRIX_SIZE-1];

    /*
    generate
        for (genvar i = 0; i < `MATRIX_SIZE; i++) begin : GEN_ROW
            for (genvar j = i; j < `MATRIX_SIZE; j++) begin : GEN_COL
                if (i == j) begin : GEN_DIAG
                    if (i == 0) begin : DU_FIRST
                        Delay_Unit u_DU (
                            .clk(clk),
                            .rst_n(rst_n),
                            .InMode(InMode),
                            .In(InData[0]),
                            .Out(X_h[0][0]),
                            .OutMode(Mode_r[0][0]));
                    end
                    else if(i==`MATRIX_SIZE-1) begin : DU_LAST
                         Delay_Unit u_DU (
                            .clk(clk),
                            .rst_n(rst_n),
                            .InMode(1'b0),
                            .In(Y_v[i-1][j]),
                            .Out(X_h[i][j]),
                            .OutMode());                       
                    end
                    else begin : DU_MID
                        Delay_Unit u_DU (
                            .clk(clk),
                            .rst_n(rst_n),
                            .InMode(Mode_r[i-1][j]),
                            .In(Y_v[i-1][j]),
                            .Out(X_h[i][j]),
                            .OutMode(Mode_r[i][j]));
                    end
                end 
                else begin : GEN_OFFDIAG
                    CORDIC_PE u_PE (
                        .clk(clk),
                        .rst_n(rst_n),
                        .InMode(Mode_r[i][j-1]),
                        .InX(X_h[i][j-1]),
                        .InY((i == 0) ? InData[j] : Y_v[i-1][j]),
                        .OutX(X_h[i][j]),
                        .OutY(Y_v[i][j]),
                        .OutMode(Mode_r[i][j]));
                end
            end
            assign OutData[i] = X_h[i][`MATRIX_SIZE-1];
        end
    endgenerate
    */

    Delay_Unit ROW0_COL0(
        .clk(clk),
        .rst_n(rst_n),
        .InMode(InMode),
        .In(InData[0]),
        .Out(X_h[0][0]),
        .OutMode(Mode_r[0][0]));
    
    CORDIC_PE ROW0_COL1(
        .clk(clk),
        .rst_n(rst_n),
        .InMode(Mode_r[0][0]),
        .InX(X_h[0][0]),
        .InY(InData[1]),
        .OutX(X_h[0][1]),
        .OutY(Y_v[0][1]),
        .OutMode(Mode_r[0][1]));
    
    CORDIC_PE ROW0_COL2(
        .clk(clk),
        .rst_n(rst_n),
        .InMode(Mode_r[0][1]),
        .InX(X_h[0][1]),
        .InY(InData[2]),
        .OutX(X_h[0][2]),
        .OutY(Y_v[0][2]),
        .OutMode(Mode_r[0][2]));

    Delay2_Unit ROW1_COL1(
        .clk(clk),
        .rst_n(rst_n),
        .InMode(Mode_r[0][1]),
        .In(Y_v[0][1]),
        .Out(X_h[1][1]),
        .OutMode(Mode_r[1][1]));

    CORDIC_PE ROW1_COL2(
        .clk(clk),
        .rst_n(rst_n),
        .InMode(Mode_r[1][1]),
        .InX(X_h[1][1]),
        .InY(Y_v[0][2]),
        .OutX(X_h[1][2]),
        .OutY(Y_v[1][2]),
        .OutMode(Mode_r[1][2]));
    
    assign X_h[2][2] = Y_v[1][2];

    always_comb begin    
        for(int m = 0; m < `MATRIX_SIZE; m++) OutData[m] = X_h[m][`MATRIX_SIZE-1];
    end
    

endmodule

module Delay_Unit(
    input clk,
    input rst_n,
    input InMode,
    input signed [`DATA_WIDTH-1:0] In,
    output logic signed [`DATA_WIDTH-1:0] Out,
    output logic OutMode
    );
    
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin 
            Out <= 0;
            OutMode <= 0;
        end
        else begin 
            Out <= In;
            OutMode <= InMode;
        end
    end

endmodule

module Delay2_Unit(
    input clk,
    input rst_n,
    input InMode,
    input signed [`DATA_WIDTH-1:0] In,
    output logic signed [`DATA_WIDTH-1:0] Out,
    output logic OutMode
    );
    
    logic signed [`DATA_WIDTH-1:0] In_r;
    logic InMode_r [0:1];

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin 
            Out <= 0;
            OutMode <= 0;
            In_r <= 0;
            InMode_r[0] <= 0;
            InMode_r[1] <= 0;
        end
        else begin 
            In_r <= In;
            InMode_r[0] <= InMode;
            InMode_r[1] <= InMode_r[0];
            Out <= In_r;
            OutMode <= InMode_r[1];
        end
    end

endmodule

