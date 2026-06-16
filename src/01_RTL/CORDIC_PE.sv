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
    input Pass,
    input signed [`DATA_WIDTH-1:0] InX,
    input signed [`DATA_WIDTH-1:0] InY,
    output logic signed [`DATA_WIDTH-1:0] OutX,
    output logic signed [`DATA_WIDTH-1:0] OutY,
    output logic signed OutMode
    );

    // Number of CORDIC iterations before the pipeline register.
    localparam J = 5;

    // Register
    logic signed [`DATA_WIDTH-1:0] X_r [0:`PIPE_STAGE-1];
    logic signed [`DATA_WIDTH-1:0] Y_r [0:`PIPE_STAGE-1];
    logic InFlip;
    logic Mode_r [0:`PIPE_STAGE-1];
    logic Pass_r [0:`PIPE_STAGE-1];

    // Rotational Direction from Vectoring Mode
    logic [`ITERATION-1:0] DIR_r;

    // CORDIC Core Combinational Net
    logic signed [`DATA_WIDTH-1:0] X [0:`PIPE_STAGE-1];
    logic signed [`DATA_WIDTH-1:0] Y [0:`PIPE_STAGE-1];
    logic signed [`DATA_WIDTH-1:0] DX [0:`PIPE_STAGE-1];
    logic signed [`DATA_WIDTH-1:0] DY [0:`PIPE_STAGE-1];

    // Output Magnitude Scaling Combinational Net
    logic signed [`DATA_WIDTH*2-1:0] X_Mul;
    logic signed [`DATA_WIDTH*2-1:0] Y_Mul;

    always_ff @(posedge clk or negedge rst_n) begin : INITIAL_STAGE
        if(!rst_n) begin
            X_r[0] <= 0;
            Y_r[0] <= 0;
            InFlip <= 0;
            Mode_r[0] <= 0;
            Pass_r[0] <= 0;
        end
        else begin
            if(Pass) begin
                X_r[0] <= InX;
                Y_r[0] <= InY;
                Pass_r[0] <= Pass;
            end
            else begin
                Pass_r[0] <= 0;
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
    end

    generate
        for(genvar s=0; s < `PIPE_STAGE; s++) begin : PIPELINE_BLOCK
            localparam STAGE_ITER = (s == 0) ? J : (`ITERATION - J);
            localparam ITER_OFFSET = (s == 0) ? 0 : J;
            logic [STAGE_ITER-1:0] DIR_stage;

            always_comb begin : ITERATION_STAGE
                if(Pass_r[s]) begin
                    X[s] = X_r[s];
                    Y[s] = Y_r[s];
                    DX[s] = 0;
                    DY[s] = 0;
                    for(int i = 0; i < STAGE_ITER; i++)
                        DIR_stage[i] = 0;
                end
                else begin
                    X[s] = X_r[s];
                    Y[s] = Y_r[s];
                    if(!Mode_r[s]) begin : ROTAIOTN_CORE
                        for(int i = 0; i < STAGE_ITER; i++) begin
                            DX[s] = Y[s] >>> (ITER_OFFSET+i);
                            DY[s] = X[s] >>> (ITER_OFFSET+i);
                            if(DIR_r[ITER_OFFSET+i]) begin
                                X[s] = X[s] + DX[s];
                                Y[s] = Y[s] - DY[s];
                            end
                            else begin
                                X[s] = X[s] - DX[s];
                                Y[s] = Y[s] + DY[s];
                            end
                            DIR_stage[i] = 0;
                        end
                    end
                    else begin : VECTORING_CORE
                        for(int i = 0; i < STAGE_ITER; i++) begin
                            DX[s] = Y[s] >>> (ITER_OFFSET+i);
                            DY[s] = X[s] >>> (ITER_OFFSET+i);
                            if(Y[s][`DATA_WIDTH-1]) begin
                                X[s] = X[s] - DX[s];
                                Y[s] = Y[s] + DY[s];
                                DIR_stage[i] = 0;
                            end
                            else begin
                                X[s] = X[s] + DX[s];
                                Y[s] = Y[s] - DY[s];
                                DIR_stage[i] = 1;
                            end
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
                        Pass_r[s+1] <= 0;
                    end
                    else begin
                        X_r[s+1] <= X[s];
                        Y_r[s+1] <= Y[s];
                        Mode_r[s+1] <= Mode_r[s];
                        Pass_r[s+1] <= Pass_r[s];
                    end
                end
            end
            // Capture DIR
            always_ff @(posedge clk or negedge rst_n) begin : CAPTURE_DIR
                if(!rst_n) begin
                    for(int i = 0; i < STAGE_ITER; i++)
                        DIR_r[ITER_OFFSET+i] <= 0;
                end
                else begin
                    for(int i = 0; i < STAGE_ITER; i++) begin
                        if(!Mode_r[s])
                            DIR_r[ITER_OFFSET+i] <= DIR_r[ITER_OFFSET+i];
                        else
                            DIR_r[ITER_OFFSET+i] <= DIR_stage[i];
                    end
                end
            end
        end
    endgenerate

    always_comb begin : OUTPUT_BLOCK
        if(Pass_r[`PIPE_STAGE-1]) begin
            X_Mul = 0;
            Y_Mul = 0;
            OutX = X[`PIPE_STAGE-1];
            OutY = Y[`PIPE_STAGE-1];
            OutMode = 0;
        end
        else begin
            X_Mul = X[`PIPE_STAGE-1] * `K_INV;
            OutX = X_Mul[`DATA_WIDTH + `K_INV_FRAC - 1 : `K_INV_FRAC];
            Y_Mul = Y[`PIPE_STAGE-1] * `K_INV;
            OutY = Y_Mul[`DATA_WIDTH + `K_INV_FRAC - 1 : `K_INV_FRAC];
            OutMode = Mode_r[`PIPE_STAGE-1];
        end
    end

endmodule
