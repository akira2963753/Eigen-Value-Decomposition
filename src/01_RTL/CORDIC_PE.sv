/******************************************************************************
* Copyright (C) 2026 Marco & Innis
*
* File Name:    CORDIC_PE.sv
* Project:      [Final Project] 2026 Spring DSP In VLSI @NTU <ICDA5003>
* Module:       CORDIC_PE with Vectoring & Rotation Mode for EVD
* Author:       Marco <harry2963753@gmail.com>
* Student ID:   M11407439 & B11107027
* Tool:         VCS & Verdi
* PS:           Mode=0: Vectoring / Mode=1: Rotation
*
******************************************************************************/

`define DATA_WIDTH  
`define PIPE_STAGE  2
`define ITERATION   8

module CORDIC_PE(
    input clk,
    input rst_n,
    input Mode,
    input signed [`DATA_WIDTH-1:0] InX,
    input signed [`DATA_WIDTH-1:0] InY,
    output logic signed [`DATA_WIDTH-1:0] OutX,
    output loigc signed [`DATA_WIDTH-1:0] OutY);

    localparam J = `ITERATION / `PIPE_STAGE;

    // Register
    logic signed [`DATA_WIDTH-1:0] X_r [0:`PIPE_STAGE-1];
    logic signed [`DATA_WIDTH-1:0] Y_r [0:`PIPE_STAGE-1];
    logic InFlip;
    logic Mode_r [0:`PIPE_STAGE-1];

    // Rotational Direction from Vectoring Mode
    logic [`ITERATION-1:0] DIR;
    logic [`ITERATION-1:0] DIR_r;

    // Combinational Wire
    logic signed [`DATA_WIDTH-1:0] X [0:`PIPE_STAGE-1];
    logic signed [`DATA_WIDTH-1:0] Y [0:`PIPE_STAGE-1];
    logic signed [`DATA_WIDTH-1:0] DX [0:`PIPE_STAGE-1];
    logic signed [`DATA_WIDTH-1:0] DY [0:`PIPE_STAGE-1];

    always_ff @(posedge clk or negedge rst_n) begin : INITIAL_STAGE
        if(!rst_n) begin
            X_r[0] <= 0;
            Y_r[0] <= 0;
            InFlip <= 0;
            Mode_r[0] <= 0;
        end
        else begin
            if(Mode == 0) begin
                // Initial Processing
                X_r[0] <= (InX < 0)? -InX : InX;
                Y_r[0] <= (InX < 0)? -InY : InY;
                InFlip <= (InX < 0);
                Mode_r[0] <= Mode;
            end
            else begin
                X_r[0] <= (InFlip)? -InX : InX;
                Y_r[0] <= (InFlip)? -InY : InY;
                Mode_r[0] <= Mode;
            end
        end
    end

    genvar s;
    generate
        for(s=0; s < `PIPE_STAGE; s++) begin : PIPELINE_BLOCK
            always_comb begin : ITERATION_STAGE
                if(Mode_r[s]) begin : ROTAIOTN_CORE
                    X[s] = X_r[s];
                    Y[s] = Y_r[s];                   
                    for(int  i = 0; i < J; i++) begin
                        DX[s] = Y[s] >>> (s*J+i);
                        DY[s] = X[s] >>> (s*J+i);
                        if(DIR_r[s*J+i]) begin 
                            X[s] = X[s] + DX[s];
                            Y[s] = Y[s] - DY[s];
                        end
                        else begin
                            X[s] = X[s] - DX[s];
                            Y[s] = Y[s] + DY[s];
                        end
                        DIR[s*J+i] = 0; 
                    end
                end
                else begin : VECTORING_CORE
                    X[s] = X_r[s];
                    Y[s] = Y_r[s];
                    for(int i = 0; i < J; i++) begin
                        DX[s] = Y[s] >>> (s*J+i);
                        DY[s] = X[s] >>> (s*J+i);
                        if(Y[s][`DATA_WIDTH-1]) begin
                            X[s] = X[s] - DX[s];
                            Y[s] = Y[s] + DY[s];
                            DIR[s*J+i] = 0;
                        end
                        else begin 
                            X[s] = X[s] + DX[s];
                            Y[s] = Y[s] - DY[s];
                            DIR[s*J+i] = 1;
                        end
                    end
                end
            end
            // Pipeline Pass
            if(s < `PIPE_STAGE-1) begin : PIPELINE_STAGE
                always_ff @(posedge clk or negedge rst_n) begin
                    if(!rst_n) begin
                        X_r[s+1] <= 0;
                        Y_r[s+1] <= 0;
                        Mode_r[s+1] <= 0;
                    end
                    else begin
                        X_r[s+1] <= X[s];
                        Y_r[s+1] <= Y[s];
                        Mode_r[s+1] <= Mode_r[s];
                    end
                end
            end
            // Capture DIR
            always_ff @(posedge clk or negedge rst_n) begin : CAPTURE_DIR
                if(!rst_n) for (int i = 0; i < J; i++) DIR_r[s*J+i] <= 0;
                else begin
                    for(int i = 0; i < J; i++) begin 
                        if(Mode_r[s]) DIR_r[s*J+i] <= DIR_r[s*J+i];
                        else DIR_r[s*J+i] <= DIR[s*J+i];
                    end                    
                end
            end
        end
    endgenerate

endmodule