/******************************************************************************
* Copyright (C) 2026 Marco & Innis
*
* File Name:    CORDIC_PE.sv
* Project:      [Final Project] 2026 Spring DSP In VLSI @NTU <ICDA5003>
* Module:       CORDIC_PE with Vectoring & Rotation Mode for EVD
* Author:       Marco <harry2963753@gmail.com>
* Student ID:   M11407439 & B11107027
* Tool:         VCS & Verdi
* Mode:         1: Vectoring / 0: Rotation
*
******************************************************************************/
`include "define.vh" 

module CORDIC_PE (
    input clk,
    input rst_n,
    input InMode,
    input signed [`DATA_WIDTH-1:0] InX,
    input signed [`DATA_WIDTH-1:0] InY,
    output logic signed [`DATA_WIDTH-1:0] OutX,
    output logic signed [`DATA_WIDTH-1:0] OutY,
    output logic signed OutMode
    );

    localparam J = `ITERATION / `PIPE_STAGE;

    // Register
    logic signed [`DATA_WIDTH-1:0] X_r [0:`PIPE_STAGE-1];
    logic signed [`DATA_WIDTH-1:0] Y_r [0:`PIPE_STAGE-1];
    logic InFlip;
    logic Mode_r [0:`PIPE_STAGE-1];

    // Rotational Direction from Vectoring Mode
    logic [`ITERATION-1:0] DIR;
    logic [`ITERATION-1:0] DIR_r;

    // CORDIC Core Combinational Net
    logic signed [`DATA_WIDTH-1:0] X [0:`PIPE_STAGE-1];
    logic signed [`DATA_WIDTH-1:0] Y [0:`PIPE_STAGE-1];
    logic signed [`DATA_WIDTH-1:0] DX [0:`PIPE_STAGE-1];
    logic signed [`DATA_WIDTH-1:0] DY [0:`PIPE_STAGE-1];

    // Output Magnitude Scaling Combinational Net
    logic signed [`DATA_WIDTH-1:0] X_A;
    logic signed [`DATA_WIDTH-1:0] X_B;
    logic signed [`DATA_WIDTH-1:0] Y_A; 
    logic signed [`DATA_WIDTH-1:0] Y_B;

    always_ff @(posedge clk or negedge rst_n) begin : INITIAL_STAGE
        if(!rst_n) begin
            X_r[0] <= 0;
            Y_r[0] <= 0;
            InFlip <= 0;
            Mode_r[0] <= 0;
        end
        else begin
            if(InMode) begin
                // Initial Processing
                X_r[0] <= (InX < 0)? -InX : InX;
                Y_r[0] <= (InX < 0)? -InY : InY;
                InFlip <= (InX < 0);
                Mode_r[0] <= InMode;
            end
            else begin
                X_r[0] <= (InFlip)? -InX : InX;
                Y_r[0] <= (InFlip)? -InY : InY;
                Mode_r[0] <= InMode;
            end
        end
    end

    generate
        for(genvar s=0; s < `PIPE_STAGE; s++) begin : PIPELINE_BLOCK
            always_comb begin : ITERATION_STAGE
                X[s] = X_r[s];
                Y[s] = Y_r[s];   
                if(!Mode_r[s]) begin : ROTAIOTN_CORE                
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
                        if(!Mode_r[s]) DIR_r[s*J+i] <= DIR_r[s*J+i];
                        else DIR_r[s*J+i] <= DIR[s*J+i];
                    end                    
                end
            end
        end
    endgenerate

    always_comb begin : OUTPUT_BLOCK
        if(!Mode_r[`PIPE_STAGE-1]) begin
            X_A = (X[`PIPE_STAGE-1] >>> 1) + (X[`PIPE_STAGE-1] >>> 3);
            X_B = (X[`PIPE_STAGE-1] >>> 6) + (X[`PIPE_STAGE-1] >>> 9);
            Y_A = (Y[`PIPE_STAGE-1] >>> 1) + (Y[`PIPE_STAGE-1] >>> 3);
            Y_B = (Y[`PIPE_STAGE-1] >>> 6) + (Y[`PIPE_STAGE-1] >>> 9);
            OutX = X_A - X_B;
            OutY = Y_A - Y_B;            
        end
        else begin
            X_A = (X[`PIPE_STAGE-1] >>> 1) + (X[`PIPE_STAGE-1] >>> 3);
            X_B = (X[`PIPE_STAGE-1] >>> 6) + (X[`PIPE_STAGE-1] >>> 9);
            Y_A = 0;
            Y_B = 0;
            OutX = X_A - X_B;
            OutY = 0;
        end
        OutMode = Mode_r[`PIPE_STAGE-1];
    end

endmodule