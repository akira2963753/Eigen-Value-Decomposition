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

    typedef enum logic [1:0] {IDLE, PROCESS, OUT} STATETYPE; 
    STATETYPE state, next_state;
    logic [3:0] cnt;
    logic [2:0] iter_cnt;
    logic ExIn;

    logic signed [`DATA_WIDTH-1:0] U_REG [0:`MATRIX_SIZE-1][0:`MATRIX_SIZE-1];
    logic signed [`DATA_WIDTH-1:0] EV_REG [0:`MATRIX_SIZE-1];
    logic signed [`DATA_WIDTH-1:0] IDUIn [0:`MATRIX_SIZE-1];
    logic signed [`DATA_WIDTH-1:0] IDUOut [0:`MATRIX_SIZE-1];
    logic signed [`DATA_WIDTH-1:0] OutD_BUF [0:1];
    logic signed [`DATA_WIDTH-1:0] QRDOut [0:`MATRIX_SIZE-1];
    
    always_ff @(posedge clk or negedge rst_n) begin : FSM
        if(!rst_n) state <= IDLE;
        else state <= next_state;
    end
    
    always_comb begin : FSM_CONTROLL
        case(state)
            IDLE: begin // 當 InValid = 1 時，啟動 EVD
                next_state = (InValid)? PROCESS : IDLE;
            end
            PROCESS: begin
                next_state = (iter_cnt==3'd7 && cnt==4'd2)? OUT : PROCESS;
            end
            OUT: begin
                next_state = (cnt==4'd6)? IDLE : OUT;
            end
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin : COUNTER
        if(!rst_n) cnt <= 0;
        else if(state==PROCESS) cnt <= (cnt==4'd12)? 0 : cnt + 1;
        else if(state==OUT) cnt <= cnt + 1;
        else cnt <= 0;
    end

    always_ff @(posedge clk or negedge rst_n) begin : ITERATION
        if(!rst_n) iter_cnt <= 0;
        else if(cnt==4'd12) iter_cnt <= iter_cnt + 1; 
    end

    always_ff @(posedge clk) begin : EXIN_SIGNAL
        if(state==IDLE) ExIn <= 1;
        else if(cnt==4'd8) ExIn <= 0; 
    end

    IDU u_IDU(
        .clk(clk),
        .rst_n(rst_n),
        .InData(IDUIn),
        .OutData(IDUOut));

    always_comb begin : INPUT_PROCESSOR
        if(state==PROCESS) begin
            case(cnt) 
                4'd0: begin
                    if(ExIn) begin
                        for(int m = 0; m < `MATRIX_SIZE; m++) IDUIn[m] = InData[m];
                    end 
                    else begin
                        IDUIn[0] = OutD_BUF[1];
                        IDUIn[1] = 0;
                        IDUIn[2] = 0;
                    end
                end
                4'd1: begin
                    if(ExIn) begin
                        for(int m = 0; m < `MATRIX_SIZE; m++) IDUIn[m] = InData[m];
                    end 
                    else begin
                        IDUIn[0] = OutD_BUF[1];
                        IDUIn[1] = QRDOut[1];
                        IDUIn[2] = 0;
                    end                    
                end
                4'd2: begin
                    if(ExIn) begin
                        for(int m = 0; m < `MATRIX_SIZE; m++) IDUIn[m] = InData[m];
                    end 
                    else begin
                        IDUIn[0] = OutD_BUF[1];
                        IDUIn[1] = QRDOut[1];
                        IDUIn[2] = QRDOut[2];
                    end                    
                end
                4'd3: for(int m = 0; m < `MATRIX_SIZE; m++) IDUIn[m] = U_REG[0][m];
                4'd4: for(int m = 0; m < `MATRIX_SIZE; m++) IDUIn[m] = U_REG[1][m];
                4'd5: for(int m = 0; m < `MATRIX_SIZE; m++) IDUIn[m] = U_REG[2][m];
                4'd6: begin
                    IDUIn[0] = OutD_BUF[1];
                    IDUIn[1] = 0;
                    IDUIn[2] = 0;
                end
                4'd7: begin
                    IDUIn[0] = OutD_BUF[1];
                    IDUIn[1] = QRDOut[1];
                    IDUIn[2] = 0;
                end
                4'd8: begin
                    IDUIn[0] = OutD_BUF[1];
                    IDUIn[1] = QRDOut[1];
                    IDUIn[2] = QRDOut[2];
                end
                default: for(int m = 0; m < `MATRIX_SIZE; m++) IDUIn[m] = 0;
            endcase
        end
        else for(int m = 0; m < `MATRIX_SIZE; m++) IDUIn[m] = 0;
    end

    always_ff @(posedge clk) begin : U_REG
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
                    4'd7: begin
                        U_REG[0][0] <= QRDOut[0];
                    end
                    4'd8: begin
                        U_REG[0][1] <= QRDOut[0];
                    end
                    4'd9: begin
                        U_REG[0][2] <= QRDOut[0];
                        U_REG[1][0] <= QRDOut[1];
                        U_REG[2][0] <= QRDOut[2];
                    end
                    4'd10: begin
                        U_REG[1][1] <= QRDOut[1];
                        U_REG[2][1] <= QRDOut[2];                        
                    end
                    4'd11: begin
                        U_REG[1][2] <= QRDOut[1];
                        U_REG[2][2] <= QRDOut[2];                        
                    end
                endcase
            end
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin : OUTPUT_BUFFER
        if(!rst_n) for(int m = 0; m < 2; m++) begin 
            OutD_BUF[m] <= 0;
        end
        else begin 
            OutD_BUF[1] <= OutD_BUF[0];
            OutD_BUF[0] <= QRDOut[0];
        end
    end

    QRD u_QRD(
        .clk(clk),
        .rst_n(rst_n),
        .InMode(),
        .InData(IDUOut),
        .OutData(QRDOut));

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            for(int m = 0; m < `MATRIX_SIZE; m++) EV_REG[m] <= 0;
        end
        else if(state==PROCESS && iter_cnt == 4'd7) begin
            case(cnt) 
                4'd0: EV_REG[0] <= OutD_BUF[1];
                4'd1: EV_REG[1] <= QRDOut[1];
                4'd2: EV_REG[2] <= QRDOut[2];
            endcase
        end
    end

    always_comb begin: OUTPUT_BLOCK 
        if(state==OUT) begin
            OutValid = 1;
            case(cnt)
                4'd3: for(int m = 0; m < `MATRIX_SIZE; m++) OutData[m] = EV_REG[m]; 
                4'd4: for(int m = 0; m < `MATRIX_SIZE; m++) OutData[m] = U_REG[m][0];
                4'd5: for(int m = 0; m < `MATRIX_SIZE; m++) OutData[m] = U_REG[m][1];
                4'd6: for(int m = 0; m < `MATRIX_SIZE; m++) OutData[m] = U_REG[m][2];
                default: for(int m = 0; m < `MATRIX_SIZE; m++) OutData[m] = 0;
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
    output signed [`DATA_WIDTH-1:0] OutData [0:`MATRIX_SIZE-1]
    );

    logic signed [`DATA_WIDTH-1:0] InBUF [0:2];

    always_comb begin : INBUF_OUT_BLOCK
        OutData[0] = InData[0];
        OutData[1] = InBUF[0];
        OutData[2] = InBUF[2];
    end

    always_ff @(posedge clk or negedge rst_n) begin : INBUF_BLOCK
        if(!rst_n) for(int m = 0; m < 3; m++) InBUF[m] <= 0; 
        else begin
            InBUF[0] <= InData[1];
            InBUF[1] <= InData[2];
            InBUF[2] <= InBUF[1];
        end
    end

endmodule