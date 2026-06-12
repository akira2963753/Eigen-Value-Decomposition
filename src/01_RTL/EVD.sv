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
    output logic signed [`DATA_WIDTH-1:0] OutData [0:`MATRIX_SIZE-1],
    output logic OutValid
    );

    typedef enum logic [1:0] {IDLE, PROCESS, OUT} STATETYPE; 
    STATETYPE state, next_state;
    logic [1:0] io_cnt;
    logic [3:0] cnt;
    logic [2:0] iter_cnt;
    logic InMode;

    logic signed [`DATA_WIDTH-1:0] U_REG [0:`MATRIX_SIZE-1][0:`MATRIX_SIZE-1];
    logic signed [`DATA_WIDTH-1:0] EV_REG [0:`MATRIX_SIZE-1];
    logic signed [`DATA_WIDTH-1:0] IDUIn [0:`MATRIX_SIZE-1];
    logic signed [`DATA_WIDTH-1:0] IDUOut [0:`MATRIX_SIZE-1];
    logic signed [`DATA_WIDTH-1:0] QRDOut [0:`MATRIX_SIZE-1];
    logic signed [`DATA_WIDTH-1:0] TEMP [0:2];
    
    
    always_ff @(posedge clk or negedge rst_n) begin : FSM
        if(!rst_n) state <= IDLE;
        else state <= next_state;
    end
    
    always_comb begin : FSM_CONTROLL
        case(state)
            IDLE: begin // 當 InValid = 1 時，啟動 EVD
                next_state = (InValid && io_cnt == 2'd2)? PROCESS : IDLE;
            end
            PROCESS: begin
                next_state = (iter_cnt==3'd7)? OUT : PROCESS;
            end
            OUT: begin
                next_state = (io_cnt==4'd3)? IDLE : OUT;
            end
            default: next_state = 0;
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin : IO_COUNTER
        if(!rst_n) io_cnt <= 0;
        else if(state==IDLE&&InValid) io_cnt <= io_cnt + 1;
        else if(state==OUT) io_cnt <= io_cnt + 1;
        else io_cnt <= 0;
    end

    always_ff @(posedge clk or negedge rst_n) begin : COUNTER
        if(!rst_n) cnt <= 0;
        else if(state==PROCESS) cnt <= (cnt==4'd14)? 0 : cnt + 1;
        else if(state==OUT) cnt <= cnt + 1;
        else cnt <= 0;
    end

    always_ff @(posedge clk or negedge rst_n) begin : ITERATION
        if(!rst_n) iter_cnt <= 0;
        else if(cnt==4'd14) iter_cnt <= iter_cnt + 1; 
    end

    IDU u_IDU(
        .clk(clk),
        .rst_n(rst_n),
        .InData(IDUIn),
        .OutData(IDUOut));

    always_comb begin : INPUT_PROCESSOR
        if(state==IDLE&&InValid) begin
            InMode = (io_cnt==0);
            for(int m = 0; m < `MATRIX_SIZE; m++) IDUIn[m] = InData[m];
        end
        else if(state==PROCESS) begin
            InMode = (cnt==4'd12);
            case(cnt) 
                4'd0: for(int m = 0; m < `MATRIX_SIZE; m++) IDUIn[m] = U_REG[m][0];
                4'd1: for(int m = 0; m < `MATRIX_SIZE; m++) IDUIn[m] = U_REG[m][1];
                4'd2: for(int m = 0; m < `MATRIX_SIZE; m++) IDUIn[m] = U_REG[m][2];
                4'd5: begin
                    IDUIn[0] = TEMP[0];     // R00
                    IDUIn[1] = TEMP[1];     // R01
                    IDUIn[2] = TEMP[2];     // R02
                end
                4'd6: begin
                    IDUIn[0] = 0;           // R10
                    IDUIn[1] = TEMP[0];     // R11
                    IDUIn[2] = QRDOut[1];   // R12
                end
                4'd7: begin
                    IDUIn[0] = 0;           // R20
                    IDUIn[1] = 0;           // R21
                    IDUIn[2] = TEMP[1];     // R22
                end
                4'd12: begin
                    IDUIn[0] = TEMP[0];     // T00
                    IDUIn[1] = QRDOut[1];   // T10
                    IDUIn[2] = QRDOut[2];   // T20           
                end
                4'd13: begin
                    IDUIn[0] = TEMP[1];     // T01
                    IDUIn[1] = QRDOut[1];   // T11
                    IDUIn[2] = QRDOut[2];   // T21           
                end
                4'd14: begin
                    IDUIn[0] = TEMP[2];     // T02
                    IDUIn[1] = QRDOut[1];   // T12
                    IDUIn[2] = QRDOut[2];   // T22                       
                end
                default: for(int m = 0; m < `MATRIX_SIZE; m++) IDUIn[m] = 0;
            endcase
        end
        else begin 
            for(int m = 0; m < `MATRIX_SIZE; m++) IDUIn[m] = 0;
            InMode = 0;
        end
    end

    always_ff @(posedge clk) begin : U_REG_BLOCK
        if(state==IDLE) begin
            for(int m = 0; m < `MATRIX_SIZE; m++) begin
                for(int n = 0; n < `MATRIX_SIZE; n++) begin
                    U_REG[m][n] <= (m==n)? `I : 0;
                end
            end
        end
        else begin
            if(state == PROCESS) begin
                case(cnt) 
                    4'd5: begin
                        U_REG[0][0] <= QRDOut[0];
                    end
                    4'd6: begin
                        U_REG[0][1] <= QRDOut[0];
                    end
                    4'd7: begin
                        U_REG[0][2] <= QRDOut[0];
                        U_REG[1][0] <= QRDOut[1];
                        U_REG[2][0] <= QRDOut[2];
                    end
                    4'd8: begin
                        U_REG[1][1] <= QRDOut[1];
                        U_REG[2][1] <= QRDOut[2];                        
                    end
                    4'd9: begin
                        U_REG[1][2] <= QRDOut[1];
                        U_REG[2][2] <= QRDOut[2];                        
                    end
                endcase
            end
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin : OUTPUT_BUFFER
        if(!rst_n) for(int m = 0; m < 4; m++) begin 
            TEMP[m] <= 0;
        end
        else begin 
            case(cnt) 
                4'd2: TEMP[0] <= QRDOut[0];     // Save R00
                4'd3: TEMP[1] <= QRDOut[0];     // Save R01
                4'd4: TEMP[2] <= QRDOut[0];     // Save R02
                4'd5: TEMP[0] <= QRDOut[1];     // Save R11
                4'd6: TEMP[1] <= QRDOut[2];     // Save R22
                4'd10: TEMP[0] <= QRDOut[0];    // Save T00
                4'd11: TEMP[1] <= QRDOut[0];    // Save T01
                4'd12: TEMP[2] <= QRDOut[0];    // Save T02 
            endcase
        end
    end

    QRD u_QRD(
        .clk(clk),
        .rst_n(rst_n),
        .InMode(InMode),
        .InData(IDUOut),
        .OutData(QRDOut));

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            for(int m = 0; m < `MATRIX_SIZE; m++) EV_REG[m] <= 0;
        end
        else if(state==PROCESS && iter_cnt == 4'd6) begin
            case(cnt) 
                4'd10: EV_REG[0] <= QRDOut[0];  // T00 
                4'd13: EV_REG[1] <= QRDOut[1];  // T11
                4'd14: EV_REG[2] <= QRDOut[2];  // T22
            endcase
        end
    end

    always_comb begin: OUTPUT_BLOCK 
        if(state==OUT) begin
            OutValid = 1;
            case(io_cnt)
                4'd0: for(int m = 0; m < `MATRIX_SIZE; m++) OutData[m] = EV_REG[m]; 
                4'd1: for(int m = 0; m < `MATRIX_SIZE; m++) OutData[m] = U_REG[0][m];
                4'd2: for(int m = 0; m < `MATRIX_SIZE; m++) OutData[m] = U_REG[1][m];
                4'd3: for(int m = 0; m < `MATRIX_SIZE; m++) OutData[m] = U_REG[2][m];
            endcase
        end
        else begin
            OutValid = 0;
            for(int m = 0; m < `MATRIX_SIZE; m++) OutData[m] = 0;
        end
    end

endmodule

// Input Delay Unit
module IDU(
    input clk,
    input rst_n,
    input signed [`DATA_WIDTH-1:0] InData [0:`MATRIX_SIZE-1],
    output logic signed [`DATA_WIDTH-1:0] OutData [0:`MATRIX_SIZE-1]
    );

    logic signed [`DATA_WIDTH-1:0] InBUF1;
    logic signed [`DATA_WIDTH-1:0] InBUF2 [0:2];

    always_comb begin : INBUF_OUT_BLOCK
        OutData[0] = InData[0];
        OutData[1] = InBUF1;
        OutData[2] = InBUF2[2];
    end

    always_ff @(posedge clk or negedge rst_n) begin : INBUF_BLOCK
        if(!rst_n) begin
            InBUF1 <= 0;
            for(int m = 0; m < 3; m++) InBUF2[m] <= 0;
        end 
        else begin
            InBUF1 <= InData[1];
            InBUF2[0] <= InData[2];
            InBUF2[1] <= InBUF2[0];
            InBUF2[2] <= InBUF2[1];
        end
    end

endmodule