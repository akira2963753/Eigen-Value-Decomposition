/******************************************************************************
* Copyright (C) 2026 Marco & Innis
*
* File Name:    TESTBED.sv
* Project:      [Final Project] 2026 Spring DSP In VLSI @NTU <ICDA5003>
* Module:       TESTBED (EVD)
* Author:       Marco <harry2963753@gmail.com>
* Student ID:   M11407439 & B11107027
* Tool:         VCS & Verdi
*
******************************************************************************/
`include "../01_RTL/define.vh"

module TESTBED();

    //=============================================================
    // ---------------------- Clock & Reset -----------------------
    //=============================================================
    logic clk, rst_n;

    initial clk = 0;
    always #(`CLK_PERIOD/2.0) clk = ~clk;

    //=============================================================
    // ----------------------- DUT Signals ------------------------
    //=============================================================
    logic in_valid;
    logic signed [`DATA_WIDTH-1:0] in_data [0:`MATRIX_SIZE-1];
    logic signed [`DATA_WIDTH-1:0] out_data [0:`MATRIX_SIZE-1];
    logic out_valid;

`ifdef GATE_SIM
    logic [`MATRIX_SIZE*`DATA_WIDTH-1:0] in_data_flat, out_data_flat;

    always_comb begin
        for (int i = 0; i < `MATRIX_SIZE; i++) begin
            in_data_flat[i*`DATA_WIDTH +: `DATA_WIDTH] = in_data[i];
            out_data[i] = out_data_flat[i*`DATA_WIDTH +: `DATA_WIDTH];
        end
    end
`endif

    //=============================================================
    // -------------------------- Memory --------------------------
    //=============================================================
    logic [`DATA_WIDTH-1:0] mem_in [0:`MATRIX_SIZE-1][0:`MATRIX_SIZE-1];
    logic signed [`DATA_WIDTH-1:0] mem_gold_ev [0:`MATRIX_SIZE-1];
    logic signed [`DATA_WIDTH-1:0] mem_gold_u [0:`MATRIX_SIZE-1][0:`MATRIX_SIZE-1];

    initial begin
        $readmemh({`DAT_PATH, "EVD_InData.dat"}, mem_in);
        $readmemh({`DAT_PATH, "EVD_GoldenEV.dat"}, mem_gold_ev);
        $readmemh({`DAT_PATH, "EVD_GoldenU.dat"}, mem_gold_u);
    end

    //=============================================================
    // ----------------------- DUT Instance -----------------------
    //=============================================================
    EVD u_dut (
        .clk(clk),
        .rst_n(rst_n),
        .InValid(in_valid),
`ifdef GATE_SIM
        .InData(in_data_flat),
        .OutData(out_data_flat),
`else
        .InData(in_data),
        .OutData(out_data),
`endif
        .OutValid(out_valid)
    );

    //=============================================================
    // ---------------- Sim Mode & SDF Annotate -------------------
    //=============================================================
    `ifdef GATE_SIM
    initial begin
        $display("===============================================");
        $display("        GATE-LEVEL SIMULATION START          ");
        $display("===============================================");
    end

    initial $sdf_annotate("../02_SYN/Netlist/EVD.sdf", u_dut);
    `else
    initial begin
        $display("===============================================");
        $display("        BEHAVIORAL SIMULATION START          ");
        $display("===============================================");
    end
    `endif

    //=============================================================
    // ------------------------- Counters -------------------------
    //=============================================================
    integer pass_cnt, fail_cnt;
    integer evd_latency_m;
    logic evd_lat_done;

    //=============================================================
    // ------------------------ Reset Task ------------------------
    //=============================================================
    task automatic reset_dut();
        rst_n = 1;
        in_valid = 0;
        for (int i = 0; i < `MATRIX_SIZE; i++) in_data[i] = 0;
        repeat(2) @(negedge clk) rst_n = ~rst_n;
    endtask

    //=============================================================
    // -------------------- Input Matrix Task ---------------------
    //=============================================================
    task automatic drive_matrix();
        for (int row = 0; row < `MATRIX_SIZE; row++) begin
            @(negedge clk);
            if (row == 0) in_valid = 1;
            for (int col = 0; col < `MATRIX_SIZE; col++) in_data[col] = mem_in[row][col];
        end
        @(negedge clk);
        in_valid = 0;
        for (int i = 0; i < `MATRIX_SIZE; i++) in_data[i] = 0;
    endtask

    //=============================================================
    // ------------------ Evaluate Latency Task -------------------
    //=============================================================

    task automatic measure_latency();
        logic prev_out;
        forever begin
            @(posedge in_valid);
            evd_latency_m = 0;
            prev_out = out_valid;
            forever begin
                @(posedge clk);
                evd_latency_m++;
                if (prev_out && !out_valid) break;
                prev_out = out_valid;
            end
            evd_lat_done = 1;
        end
    endtask

    //=============================================================
    // ------------------- Golden Result Check --------------------
    //=============================================================

    task automatic check_ev();
        logic signed [`DATA_WIDTH-1:0] act, exp;

        for (int i = 0; i < `MATRIX_SIZE; i++) begin
            act = out_data[i];
            exp = mem_gold_ev[i];
            if (act !== exp) begin
                fail_cnt++;
                $display("[FAIL] EV[%0d] act=%05h exp=%05h", i, act, exp);
            end
            else begin
                pass_cnt++;
                `ifdef VERBOSE
                $display("[PASS] EV[%0d] = %05h", i, act);
                `endif
            end
        end
    endtask

    task automatic check_u(input int col);
        logic signed [`DATA_WIDTH-1:0] act, exp;

        for (int row = 0; row < `MATRIX_SIZE; row++) begin
            act = out_data[row];
            exp = mem_gold_u[row][col];
            if (act !== exp) begin
                fail_cnt++;
                $display("[FAIL] U[%0d][%0d] act=%05h exp=%05h", row, col, act, exp);
            end
            else begin
                pass_cnt++;
                `ifdef VERBOSE
                $display("[PASS] U[%0d][%0d] = %05h", row, col, act);
                `endif
            end
        end
    endtask

    task automatic golden_check();
        wait(out_valid);
        for (int c = 0; c < 4; c++) begin
            @(posedge clk);
            if (c == 0) check_ev();
            else check_u(c - 1);
        end
    endtask

    //=============================================================
    // ------------------------ Main Flow -------------------------
    //=============================================================
    initial begin
        pass_cnt = 0;
        fail_cnt = 0;
        evd_lat_done = 0;

        $display("========================================");
        $display("  EVD Testbench Start");
        $display("  DATA_WIDTH = %0d, MATRIX_SIZE = %0d", `DATA_WIDTH, `MATRIX_SIZE);
        $display("========================================");

        fork // 用 join_none 在背景算 Cycle 數
            measure_latency();
        join_none

        reset_dut();
        drive_matrix();
        golden_check();
        wait(evd_lat_done);

        $display("");
        $display("========================================");
        $display("  EVD Verification Summary (Pattern 8)");
        $display("========================================");
        $display("  PASS : %0d / %0d", pass_cnt, pass_cnt + fail_cnt);
        $display("  FAIL : %0d / %0d", fail_cnt, pass_cnt + fail_cnt);
        $display("  Latency M : %0d cycles", evd_latency_m);
        $display("  Processing time : %0d ns (M x Ts)", evd_latency_m * `CLK_PERIOD);
        $display("========================================");
        if (fail_cnt == 0) $display("  >>> ALL TESTS PASSED <<<");
        else $display("  >>> SOME TESTS FAILED <<<");
        $display("========================================");

        repeat(10) @(posedge clk);
        $finish;
    end

    //=============================================================
    // ------------------------ FSDB Dump -------------------------
    //=============================================================
    initial begin
        $fsdbDumpfile("TESTBED.fsdb");
        $fsdbDumpvars(0, TESTBED, "+mda");
    end

    //=============================================================
    // --------------------- Timeout Watchdog ---------------------
    //=============================================================
    initial begin
        #(`CLK_PERIOD * 300);
        $display("[TB] Timeout! Simulation killed.");
        $finish;
    end

endmodule
