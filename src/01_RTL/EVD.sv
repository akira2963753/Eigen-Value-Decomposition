/******************************************************************************
* Copyright (C) 2026 Marco & Innis
*
* File Name:    EVD.sv
* Project:      [Final Project] 2026 Spring DSP In VLSI @NTU <ICDA5003>
* Module:       EVD
* Author:       Marco <harry2963753@gmail.com>
* Student ID:   M11407439 & B11107027
* Tool:         VCS & Verdi
*
******************************************************************************/
`include "define.vh" 

module EVD(
    input clk,
    input rst_n,
    input InValid,
    input signed [`DATA_WIDTH-1:0] InData [0:`MATRIX_SIZE-1],
    output signed [`DATA_WIDTH-1:0] OutData [0:`MATRIX_SIZE-1],
    output OutValid
    );

    typedef enum logic {IDLE, PROCESS_R, PROCESS_T, PROCESS_U, OUT} STATETYPE; 
    STATETYPE state, next_state;
    logic [2:0] cnt;

    logic signed [`DATA_WIDTH-1:0] BUFIn [0:`MATRIX_SIZE-1];
    logic signed [`DATA_WIDTH-1:0] BUFOut [0:`MATRIX_SIZE-1];

    always_ff @(posedge clk or negedge rst_n) begin : FSM
        if(!rst_n) state <= IDLE;
        else state <= next_state;
    end
    
    always_comb begin : FSM_CONTROLLER
        case(state)
            IDLE: begin // 當 InValid = 1 時，啟動 EVD
                next_state = (InValid)? PROCESS_R : IDLE;
            end
            PROCESS_R: begin
                next_state = (cnt==3'd4)? PROCESS_T : PROCESS_R;
            end
            PROCESS_T: begin
            end
            PROCESS_U: begin
                
            end
            OUT: begin
                
            end
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) cnt <= 0;
        else if(state==PROCESS_R) cnt <= cnt + 1;
        else cnt <= 0;
    end

    always_comb begin : INPUT_PROCESSOR
        if(state==PROCESS_R) begin
            BUFIn = InData;
        end
        else if(state==PROCESS_R) begin
            
        end
    end

    Input_Buffer u_INBUF(
        .clk(clk),
        .rst_n(rst_n),
        .InData(BUFIn),
        .OutData(BUFOut));


    QRD u_QRD(
        .clk(clk),
        .rst_n(rst_n),
        .InMode(BUFOut),
        .InData(),
        .OutData());


endmodule


module Input_Buffer(
    input clk,
    input rst_n,
    input signed [`DATA_WIDTH-1:0] InData [0:`MATRIX_SIZE-1],
    output signed [`DATA_WIDTH-1:0] OutData [0:`MATRIX_SIZE-1]
    );

    logic signed [`DATA_WIDTH-1:0] InBUF [0:2];

    always_comb begin : INBUF_OUT_BLOCK
        OutData[0] = InData[0];
        OutData[1] = InBUF[0];
        OutData[2] = InBUF[2];
    end

    always_ff @(posedge clk or negedge rst_n) begin : INBUF_BLOCK
        if(!rst_n) begin
            for(int m = 0; m < 3; m++) InBUF[m] <= 0;
        end 
        else begin
            InBUF[0] <= InData[1];
            InBUF[1] <= InData[2];
            InBUF[2] <= InBUF[1];
        end
    end

endmodule