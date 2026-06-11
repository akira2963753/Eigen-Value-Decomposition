/******************************************************************************
* Copyright (C) 2026 Marco & Innis
*
* File Name:    TESTBED.sv
* Project:      [Final Project] 2026 Spring DSP In VLSI @NTU <ICDA5003>
* Module:       TESTBED.sv for CORDIC_PE
* Author:       Marco <harry2963753@gmail.com>
* Student ID:   M11407439 & B11107027
* Tool:         VCS & Verdi
*
******************************************************************************/
`include "../01_RTL/define.vh"

module TESTBED();

    //=============================================================
    // ------------------- Configuration -------------------------
    //=============================================================
    localparam LATENCY = `PIPE_STAGE;
    localparam NUM_DATA = 165;

    //=============================================================
    // -------------------- Clock & Reset ------------------------
    //=============================================================
    logic clk, rst_n;

    initial clk = 0;
    always #(`CLK_PERIOD / 2) clk = ~clk;

    //=============================================================
    // ----------------------- DUT I/O ---------------------------
    //=============================================================
    logic in_mode;
    logic signed [`DATA_WIDTH-1:0] in_x, in_y;
    logic signed [`DATA_WIDTH-1:0] out_x, out_y;
    logic out_mode;

    //=============================================================
    // ------------------ DUT Instantiation ----------------------
    //=============================================================
    CORDIC_PE u_dut (
        .clk(clk),
        .rst_n(rst_n),
        .InMode(in_mode),
        .InX(in_x),
        .InY(in_y),
        .OutX(out_x),
        .OutY(out_y),
        .OutMode(out_mode)
    );

    //=============================================================
    // ------------- FSDB Waveform Dump (VCS / Verdi) ------------
    //=============================================================
    initial begin
        $fsdbDumpfile("TESTBED.fsdb");
        $fsdbDumpvars(0, TESTBED, "+mda");
    end

    //=============================================================
    // ----------------- Test Data Memories ----------------------
    //=============================================================
    logic mem_mode [0:NUM_DATA-1];
    logic [`DATA_WIDTH-1:0] mem_inx [0:NUM_DATA-1];
    logic [`DATA_WIDTH-1:0] mem_iny [0:NUM_DATA-1];
    logic [`DATA_WIDTH-1:0] mem_gold_x [0:NUM_DATA-1];
    logic [`DATA_WIDTH-1:0] mem_gold_y [0:NUM_DATA-1];

    initial begin
        $readmemh({`DAT_PATH, "PE_InMode.dat"}, mem_mode);
        $readmemh({`DAT_PATH, "PE_InX.dat"}, mem_inx);
        $readmemh({`DAT_PATH, "PE_InY.dat"}, mem_iny);
        $readmemh({`DAT_PATH, "PE_GoldenX.dat"}, mem_gold_x);
        $readmemh({`DAT_PATH, "PE_GoldenY.dat"}, mem_gold_y);
    end

    //=============================================================
    // ----------------------- Counters --------------------------
    //=============================================================
    integer pass_cnt, fail_cnt;

    //=============================================================
    // ------------------------ Tasks ----------------------------
    //=============================================================
    task automatic reset_dut();
        rst_n = 1;
        in_mode = 0;
        in_x = 0;
        in_y = 0;
        repeat(2) @(negedge clk) rst_n = ~rst_n;
    endtask

    task automatic drive_input(input int idx);
        in_mode = mem_mode[idx];
        in_x = mem_inx[idx];
        in_y = mem_iny[idx];
    endtask

    task automatic drive_idle();
        in_mode = 0;
        in_x = 0;
        in_y = 0;
    endtask

    task automatic check_output(input int idx);
        logic [`DATA_WIDTH-1:0] act_x, act_y, exp_x, exp_y;
        logic exp_mode;
        string mode_str;

        act_x = out_x;
        act_y = out_y;
        exp_x = mem_gold_x[idx];
        exp_y = mem_gold_y[idx];
        exp_mode = mem_mode[idx];
        mode_str = exp_mode ? "V" : "R";

        if (act_x !== exp_x || act_y !== exp_y || out_mode !== exp_mode) begin
            fail_cnt++;
            $display("[FAIL] #%3d (%s) InX=%05h InY=%05h | OutX=%05h (exp %05h) OutY=%05h (exp %05h) Mode=%0b (exp %0b)",
                     idx, mode_str,
                     mem_inx[idx], mem_iny[idx],
                     act_x, exp_x,
                     act_y, exp_y,
                     out_mode, exp_mode);
        end 
        else begin
            pass_cnt++;
            `ifdef VERBOSE
            $display("[PASS] #%3d (%s) OutX=%05h OutY=%05h", idx, mode_str, act_x, act_y);
            `endif
        end
    endtask

    //=============================================================
    // ------------------- Main Test Flow ------------------------
    //=============================================================
    initial begin
        pass_cnt = 0;
        fail_cnt = 0;

        $display("========================================");
        $display("  CORDIC_PE Testbench Start");
        $display("  DATA_WIDTH = %0d, LATENCY = %0d", `DATA_WIDTH, LATENCY);
        $display("  Test vectors: %0d", NUM_DATA);
        $display("========================================");

        reset_dut();

        for (int i = 0; i < NUM_DATA + LATENCY; i++) begin
            @(negedge clk);
            if (i < NUM_DATA) drive_input(i);
            else drive_idle();

            @(posedge clk);
            if (i >= LATENCY) check_output(i - LATENCY);
        end

        $display("");
        $display("========================================");
        $display("  CORDIC_PE Verification Summary");
        $display("========================================");
        $display("  PASS : %0d / %0d", pass_cnt, pass_cnt + fail_cnt);
        $display("  FAIL : %0d / %0d", fail_cnt, pass_cnt + fail_cnt);
        $display("========================================");
        if (fail_cnt == 0) $display("  >>> ALL TESTS PASSED <<<");
        else $display("  >>> SOME TESTS FAILED <<<");
        $display("========================================");

        #(`CLK_PERIOD * 5);
        $finish;
    end

    //=============================================================
    // ------------------- Timeout Watchdog ----------------------
    //=============================================================
    initial begin
        #(`CLK_PERIOD * (NUM_DATA + LATENCY + 100));
        $display("[TIMEOUT] Simulation exceeded expected duration.");
        $finish;
    end

endmodule
