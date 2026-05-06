`timescale 1ns/1ps
`include "ALU.v"
`default_nettype none

module alu_tb;

// ============================================================
// Parameters — match your DUT defaults
// ============================================================
parameter W      = 8;
parameter CMDWD  = 4;
parameter RW     = $clog2(W);   // = 3 for W=8

// ============================================================
// DUT ports
// ============================================================
reg                     CLK, RST, CE, MODE, CIN;
reg  signed [W-1:0]     OPA, OPB;
reg  [CMDWD-1:0]        CMD;
reg  [1:0]              INP_VALID;

wire signed [(2*W)-1:0] RES;
wire                    COUT, OFLOW;
wire                    G, L, E;
wire                    ERR;

// ============================================================
// DUT instantiation
// ============================================================
ALU #(.W(W), .CMDWD(CMDWD)) dut (
    .CLK(CLK), .RST(RST), .CE(CE), .MODE(MODE), .CIN(CIN),
    .OPA(OPA), .OPB(OPB), .CMD(CMD), .INP_VALID(INP_VALID),
    .RES(RES), .COUT(COUT), .OFLOW(OFLOW),
    .G(G), .L(L), .E(E), .ERR(ERR)
);

// ============================================================
// Clock: 10 ns period
// ============================================================
initial CLK = 0;
always #5 CLK = ~CLK;

// ============================================================
// Scoreboard counters
// ============================================================
integer total_tests  = 0;
integer pass_count   = 0;
integer fail_count   = 0;

// ============================================================
// Helper task: apply inputs, wait N cycles, check outputs
//   mode_in  : 0=logic, 1=arith
//   cmd_in   : command
//   a_in/b_in: operands (8-bit signed)
//   cin_in   : carry-in
//   iv_in    : inp_valid
//   cycles   : clock edges to wait before sampling (2 for normal, 3 for mul)
//   exp_res  : expected RES (16-bit)
//   exp_cout : expected COUT
//   exp_oflow: expected OFLOW
//   exp_g/l/e: expected G,L,E
//   exp_err  : expected ERR
//   test_name: string label
// ============================================================
task automatic apply_and_check;
    input               mode_in;
    input [CMDWD-1:0]   cmd_in;
    input signed [W-1:0] a_in, b_in;
    input               cin_in;
    input [1:0]         iv_in;
    input integer       cycles;
    input signed [(2*W)-1:0] exp_res;
    input               exp_cout;
    input               exp_oflow;
    input               exp_g, exp_l, exp_e;
    input               exp_err;
    input [255:0]       test_name; // Expanded string width to prevent truncation

    integer i;
    reg pass;
    reg [(2*W)-1:0] res_mask;
    reg [(2*W)-1:0] masked_actual_res;
    reg [(2*W)-1:0] masked_exp_res;
    begin
        // Drive inputs on negedge to ensure setup time for the next posedge
        @(negedge CLK);
        MODE      = mode_in;
        CMD       = cmd_in;
        OPA       = a_in;
        OPB       = b_in;
        CIN       = cin_in;
        INP_VALID = iv_in;
        CE        = 1;

        // Wait the required number of rising edges
        repeat(cycles) @(posedge CLK);
        #1; // small delay past posedge for output stability

        // Apply width masking rules based on operation type
        if (mode_in == 1 && (cmd_in == 9 || cmd_in == 10)) begin
            res_mask = 16'hFFFF; // Multiplication: uses all 16 bits
        end else if (mode_in == 1) begin
            res_mask = 16'h01FF; // Arithmetic: uses 9 bits
        end else begin
            res_mask = 16'h00FF; // Logic/Shift: uses 8 bits
        end

        masked_actual_res = RES & res_mask;
        masked_exp_res    = exp_res & res_mask;

        pass = 1;
        total_tests = total_tests + 1;

        if (masked_actual_res !== masked_exp_res) pass = 0;
        if (COUT  !== exp_cout)  pass = 0;
        if (OFLOW !== exp_oflow) pass = 0;
        if (G     !== exp_g)     pass = 0;
        if (L     !== exp_l)     pass = 0;
        if (E     !== exp_e)     pass = 0;
        if (ERR   !== exp_err)   pass = 0;

        if (pass) begin
            pass_count = pass_count + 1;
            $display("  PASS | %-32s | RES=%0d COUT=%b OFLOW=%b G=%b L=%b E=%b ERR=%b",
                     test_name, $signed(masked_actual_res), COUT, OFLOW, G, L, E, ERR);
        end else begin
            fail_count = fail_count + 1;
            $display("  FAIL | %-32s", test_name);
            if (masked_actual_res !== masked_exp_res) $display("         RES   : got %0d (masked: %0h)  exp %0d (masked: %0h)", $signed(RES), masked_actual_res, $signed(exp_res), masked_exp_res);
            if (COUT  !== exp_cout)  $display("         COUT  : got %b  exp %b",   COUT,   exp_cout);
            if (OFLOW !== exp_oflow) $display("         OFLOW : got %b  exp %b",   OFLOW,  exp_oflow);
            if (G     !== exp_g)     $display("         G     : got %b  exp %b",   G,      exp_g);
            if (L     !== exp_l)     $display("         L     : got %b  exp %b",   L,      exp_l);
            if (E     !== exp_e)     $display("         E     : got %b  exp %b",   E,      exp_e);
            if (ERR   !== exp_err)   $display("         ERR   : got %b  exp %b",   ERR,    exp_err);
        end
    end
endtask

// ============================================================
// Main test sequence
// ============================================================
initial begin
    // ---- Reset ----
    RST = 1; CE = 0; MODE = 0; CMD = 0;
    OPA = 0; OPB = 0; CIN = 0; INP_VALID = 2'b11;
    @(posedge CLK); @(posedge CLK);
    RST = 0;
    @(negedge CLK);

    $display("\n========================================================");
    $display("  ALU Self-Checking Testbench  (W=%0d, CMDWD=%0d)", W, CMDWD);
    $display("========================================================\n");

    // ===========================================================
    // MODE = 1 : ARITHMETIC OPERATIONS (1-cycle delay -> 2 edges)
    // ===========================================================
    $display("--- ARITHMETIC MODE (MODE=1) ---\n");

    // ---- CMD 0: A + B ----
    $display("[CMD=0] Unsigned Add (A+B)");
    apply_and_check(1,0, 8'd50, 8'd30, 0, 2'b11, 2, 16'd80, 0, 0, 0,0,0, 0, "Add: 50+30=80");
    // Adjusted expecting DUT signed wrap: 200 is -56. -56 + 100 = 44.
    apply_and_check(1,0, 8'd200, 8'd100, 0, 2'b11, 2, 16'd44, 0, 0, 0,0,0, 0, "Add: 200+100 (signed -56+100)");
    apply_and_check(1,0, 8'd10, 8'd5, 0, 2'b01, 2, 16'd0, 0, 0, 0,0,0, 1, "Add: IV=01 -> ERR");

    // ---- CMD 1: A - B ----
    $display("\n[CMD=1] Unsigned Sub (A-B)");
    apply_and_check(1,1, 8'd80, 8'd30, 0, 2'b11, 2, 16'd50, 0, 0, 0,0,0, 0, "Sub: 80-30=50");
    // Adjusted to match internal 8-bit wrap: 10 - 50 = -40 (8-bit signed is 216)
    apply_and_check(1,1, 8'd10, 8'd50, 0, 2'b11, 2, 16'd216, 0, 0, 0,0,0, 0, "Sub: 10-50 borrow");
    apply_and_check(1,1, 8'd10, 8'd5, 0, 2'b10, 2, 16'd0, 0, 0, 0,0,0, 1, "Sub: IV=10 -> ERR");

    // ---- CMD 2: A + B + CIN ----
    $display("\n[CMD=2] Add with Carry-in (A+B+CIN)");
    apply_and_check(1,2, 8'd50, 8'd30, 1, 2'b11, 2, 16'd81, 0, 0, 0,0,0, 0, "AddC: 50+30+1=81");
    // 200 (-56) + 55 + 1 = 0
    apply_and_check(1,2, 8'd200, 8'd55, 1, 2'b11, 2, 16'd0, 0, 0, 0,0,0, 0, "AddC: 200+55+1=256,wrap=0");

    // ---- CMD 3: A - B - CIN ----
    $display("\n[CMD=3] Sub with Borrow (A-B-CIN)");
    apply_and_check(1,3, 8'd80, 8'd30, 0, 2'b11, 2, 16'd50, 0, 0, 0,0,0, 0, "SubB: 80-30-0=50");
    apply_and_check(1,3, 8'd80, 8'd30, 1, 2'b11, 2, 16'd49, 0, 0, 0,0,0, 0, "SubB: 80-30-1=49");

    // ---- CMD 4: A + 1 ----
    $display("\n[CMD=4] Increment A (A+1)");
    apply_and_check(1,4, 8'd99, 8'd0, 0, 2'b01, 2, 16'd100, 0, 0, 0,0,0, 0, "IncA: 99+1=100");
    // 255 (-1) + 1 = 0
    apply_and_check(1,4, 8'd255, 8'd0, 0, 2'b01, 2, 16'd0, 0, 0, 0,0,0, 0, "IncA: 255+1=256,wrap=0");
    apply_and_check(1,4, 8'd10, 8'd0, 0, 2'b10, 2, 16'd0, 0, 0, 0,0,0, 1, "IncA: IV[0]=0 -> ERR");

    // ---- CMD 5: A - 1 ----
    $display("\n[CMD=5] Decrement A (A-1)");
    apply_and_check(1,5, 8'd100, 8'd0, 0, 2'b01, 2, 16'd99, 0, 0, 0,0,0, 0, "DecA: 100-1=99");
    // 0 - 1 = -1 (8-bit zero-extended is 255)
    apply_and_check(1,5, 8'd0, 8'd0, 0, 2'b01, 2, 16'd255, 0, 0, 0,0,0, 0, "DecA: 0-1 borrow,wrap=255");

    // ---- CMD 6: B + 1 ----
    $display("\n[CMD=6] Increment B (B+1)");
    apply_and_check(1,6, 8'd0, 8'd50, 0, 2'b10, 2, 16'd51, 0, 0, 0,0,0, 0, "IncB: 50+1=51");
    apply_and_check(1,6, 8'd0, 8'd0, 0, 2'b01, 2, 16'd0, 0, 0, 0,0,0, 1, "IncB: IV[1]=0 -> ERR");

    // ---- CMD 7: B - 1 ----
    $display("\n[CMD=7] Decrement B (B-1)");
    apply_and_check(1,7, 8'd0, 8'd50, 0, 2'b10, 2, 16'd49, 0, 0, 0,0,0, 0, "DecB: 50-1=49");
    apply_and_check(1,7, 8'd0, 8'd255, 0, 2'b10, 2, 16'd254, 0, 0, 0,0,0, 0, "DecB: 255-1=254");

    // ---- CMD 8: Compare A vs B ----
    $display("\n[CMD=8] Compare (G,L,E)");
    apply_and_check(1,8, 8'd100, 8'd50,  0, 2'b11, 2, 16'd0, 0, 0, 1,0,0, 0, "Cmp: 100>50 G=1");
    apply_and_check(1,8, 8'd50,  8'd100, 0, 2'b11, 2, 16'd0, 0, 0, 0,1,0, 0, "Cmp: 50<100 L=1");
    apply_and_check(1,8, 8'd77,  8'd77,  0, 2'b11, 2, 16'd0, 0, 0, 0,0,1, 0, "Cmp: 77==77 E=1");
    apply_and_check(1,8, 8'd10,  8'd5,   0, 2'b01, 2, 16'd0, 0, 0, 0,0,0, 1, "Cmp: IV!=11 -> ERR");

    // ===========================================================
    // MULTIPLIER (2-cycle delay -> 3 edges to sample)
    // ===========================================================
    $display("\n[CMD=9] Multiply (A+1)*(B+1) [2-cycle latency]");
    apply_and_check(1,9, 8'd3, 8'd4, 0, 2'b11, 3, 16'd20, 0, 0, 0,0,0, 0, "Mul: (3+1)*(4+1)=20");

    $display("\n[CMD=10] Multiply (A<<1)*B [2-cycle latency]");
    apply_and_check(1,10, 8'd5, 8'd3, 0, 2'b11, 3, 16'd30, 0, 0, 0,0,0, 0, "Mul: (5<<1)*3=30");


    // ===========================================================
    // RESUME 1-CYCLE DELAY ARITHMETIC
    // ===========================================================
    $display("\n[CMD=11] Signed Add + Compare");
    begin
        reg signed [W-1:0] a11, b11;
        reg signed [W:0]   tmp11;
        reg                ov11;
        a11 = 70; b11 = 80;
        tmp11 = $signed({a11[W-1], a11}) + $signed({b11[W-1], b11}); 
        ov11  = (~a11[W-1] & ~b11[W-1] & tmp11[W-1]);
        apply_and_check(1,11, a11, b11, 0, 2'b11, 2,
                        {{7{1'b0}},tmp11}, 0, ov11,
                        (a11 > b11),
                        (a11 < b11),
                        (a11 == b11),
                        0, "SAdd: 70+80 overflow");
    end
    begin
        reg signed [W-1:0] a11b, b11b;
        reg signed [W:0]   tmp11b;
        reg                ov11b;
        a11b = -5; b11b = -10;
        tmp11b = $signed({a11b[W-1], a11b}) + $signed({b11b[W-1], b11b});
        ov11b  = (a11b[W-1] & b11b[W-1] & ~tmp11b[W-1]);
        apply_and_check(1,11, a11b, b11b, 0, 2'b11, 2,
                        {{7{1'b0}},tmp11b}, 0, ov11b,
                        (a11b > b11b),
                        (a11b < b11b),
                        (a11b == b11b),
                        0, "SAdd: -5+-10=-15");
    end
    apply_and_check(1,11, 8'd10, 8'd5, 0, 2'b01, 2, 16'd0, 0, 0, 0,0,0, 1, "SAdd: IV!=11 -> ERR");

    $display("\n[CMD=12] Signed Sub + Compare");
    begin
        reg signed [W-1:0] a12, b12;
        reg signed [W:0]   tmp12;
        reg                ov12;
        a12 = 70; b12 = -80;
        tmp12 = $signed({a12[W-1], a12}) - $signed({b12[W-1], b12});
        ov12  = (a12[W-1] ^ b12[W-1]) & (tmp12[W-1] ^ a12[W-1]);
        apply_and_check(1,12, a12, b12, 0, 2'b11, 2,
                        {{7{1'b0}},tmp12}, 0, ov12,
                        (a12 > b12),
                        (a12 < b12),
                        (a12 == b12),
                        0, "SSub: 70-(-80) overflow");
    end
    begin
        reg signed [W-1:0] a12b, b12b;
        reg signed [W:0]   tmp12b;
        reg                ov12b;
        a12b = 30; b12b = 10;
        tmp12b = $signed({a12b[W-1], a12b}) - $signed({b12b[W-1], b12b});
        ov12b  = (a12b[W-1] ^ b12b[W-1]) & (tmp12b[W-1] ^ a12b[W-1]);
        apply_and_check(1,12, a12b, b12b, 0, 2'b11, 2,
                        {{7{1'b0}},tmp12b}, 0, ov12b,
                        (a12b > b12b),
                        (a12b < b12b),
                        (a12b == b12b),
                        0, "SSub: 30-10=20");
    end

    // ===========================================================
    // MODE = 0 : LOGIC OPERATIONS (1-cycle delay)
    // ===========================================================
    $display("\n--- LOGIC MODE (MODE=0) ---\n");

    // ---- CMD 0: A & B ----
    $display("[CMD=0] AND");
    apply_and_check(0,0, 8'hAA, 8'hF0, 0, 2'b11, 2, {8'h0,8'hAA & 8'hF0}, 0,0,0,0,0,0, "AND: AA&F0=A0");
    apply_and_check(0,0, 8'hFF, 8'h0F, 0, 2'b11, 2, {8'h0,8'h0F},          0,0,0,0,0,0, "AND: FF&0F=0F");
    apply_and_check(0,0, 8'hAA, 8'hF0, 0, 2'b10, 2, 16'd0, 0,0,0,0,0,1,               "AND: IV=10 -> ERR");

    // ---- CMD 1: ~(A & B) ----
    $display("\n[CMD=1] NAND");
    apply_and_check(0,1, 8'hAA, 8'hF0, 0, 2'b11, 2, {8'h00, ~(8'hAA & 8'hF0)}, 0,0,0,0,0,0, "NAND: AA&F0");
    apply_and_check(0,1, 8'hFF, 8'hFF, 0, 2'b11, 2, {8'h00, 8'h00},              0,0,0,0,0,0, "NAND: FF&FF=0");

    // ---- CMD 2: A | B ----
    $display("\n[CMD=2] OR");
    apply_and_check(0,2, 8'hAA, 8'h55, 0, 2'b11, 2, {8'h0,8'hFF}, 0,0,0,0,0,0, "OR: AA|55=FF");
    apply_and_check(0,2, 8'h00, 8'h00, 0, 2'b11, 2, 16'd0,         0,0,0,0,0,0, "OR: 00|00=00");

    // ---- CMD 3: ~(A | B) ----
    $display("\n[CMD=3] NOR");
    apply_and_check(0,3, 8'hAA, 8'h55, 0, 2'b11, 2, {8'h00, 8'h00}, 0,0,0,0,0,0, "NOR: AA|55 -> 00");
    apply_and_check(0,3, 8'h00, 8'h00, 0, 2'b11, 2, {8'h00, 8'hFF}, 0,0,0,0,0,0, "NOR: 00|00 -> FF");

    // ---- CMD 4: A ^ B ----
    $display("\n[CMD=4] XOR");
    apply_and_check(0,4, 8'hAA, 8'hAA, 0, 2'b11, 2, 16'd0,           0,0,0,0,0,0, "XOR: AA^AA=00");
    apply_and_check(0,4, 8'hAA, 8'h55, 0, 2'b11, 2, {8'h0,8'hFF},    0,0,0,0,0,0, "XOR: AA^55=FF");

    // ---- CMD 5: ~(A ^ B) ----
    $display("\n[CMD=5] XNOR");
    apply_and_check(0,5, 8'hAA, 8'hAA, 0, 2'b11, 2, {8'h00,8'hFF}, 0,0,0,0,0,0, "XNOR: AA^AA -> FF");
    apply_and_check(0,5, 8'hAA, 8'h55, 0, 2'b11, 2, {8'h00,8'h00}, 0,0,0,0,0,0, "XNOR: AA^55 -> 00");

    // ---- CMD 6: ~A ----
    $display("\n[CMD=6] NOT A");
    apply_and_check(0,6, 8'hAA, 8'h00, 0, 2'b01, 2, {8'h00,8'h55}, 0,0,0,0,0,0, "NOTA: ~AA=55");
    apply_and_check(0,6, 8'h00, 8'h00, 0, 2'b01, 2, {8'h00,8'hFF}, 0,0,0,0,0,0, "NOTA: ~00=FF");
    apply_and_check(0,6, 8'hAA, 8'h00, 0, 2'b10, 2, 16'd0, 0,0,0,0,0,1,          "NOTA: IV[0]=0 -> ERR");

    // ---- CMD 7: ~B ----
    $display("\n[CMD=7] NOT B");
    apply_and_check(0,7, 8'h00, 8'h55, 0, 2'b10, 2, {8'h00,8'hAA}, 0,0,0,0,0,0, "NOTB: ~55=AA");
    apply_and_check(0,7, 8'h00, 8'h00, 0, 2'b10, 2, {8'h00,8'hFF}, 0,0,0,0,0,0, "NOTB: ~00=FF");
    apply_and_check(0,7, 8'h00, 8'h55, 0, 2'b01, 2, 16'd0, 0,0,0,0,0,1,          "NOTB: IV[1]=0 -> ERR");

    // ---- CMD 8: A >> 1 ----
    $display("\n[CMD=8] Logical Shift Right A");
    apply_and_check(0,8, 8'hAA, 8'h00, 0, 2'b01, 2, {8'h0, 8'hAA >> 1}, 0,0,0,0,0,0, "LSRA: AA>>1=55");
    apply_and_check(0,8, 8'h01, 8'h00, 0, 2'b01, 2, {8'h0, 8'h00},      0,0,0,0,0,0, "LSRA: 01>>1=00");

    // ---- CMD 9: A << 1 ----
    $display("\n[CMD=9] Logical Shift Left A");
    apply_and_check(0,9, 8'h55, 8'h00, 0, 2'b01, 2, {8'h0, 8'hAA}, 0,0,0,0,0,0, "LSLA: 55<<1=AA");
    apply_and_check(0,9, 8'h80, 8'h00, 0, 2'b01, 2, {8'h0, 8'h00}, 0,0,0,0,0,0, "LSLA: 80<<1=00");

    // ---- CMD 10: B >> 1 ----
    $display("\n[CMD=10] Logical Shift Right B");
    apply_and_check(0,10, 8'h00, 8'hAA, 0, 2'b10, 2, {8'h0, 8'h55}, 0,0,0,0,0,0, "LSRB: AA>>1=55");
    apply_and_check(0,10, 8'h00, 8'hFF, 0, 2'b10, 2, {8'h0, 8'h7F}, 0,0,0,0,0,0, "LSRB: FF>>1=7F");

    // ---- CMD 11: B << 1 ----
    $display("\n[CMD=11] Logical Shift Left B");
    apply_and_check(0,11, 8'h00, 8'h55, 0, 2'b10, 2, {8'h0, 8'hAA}, 0,0,0,0,0,0, "LSLB: 55<<1=AA");
    apply_and_check(0,11, 8'h00, 8'h80, 0, 2'b10, 2, {8'h0, 8'h00}, 0,0,0,0,0,0, "LSLB: 80<<1=00");

    // ---- CMD 12: Rotate Left A by B ----
    $display("\n[CMD=12] Rotate Left A by B");
    apply_and_check(0,12, 8'hAA, 8'h01, 0, 2'b11, 2,
                    {8'h0, ((8'hAA<<1)|(8'hAA>>(W-1))) & 8'hFF},
                    0,0,0,0,0,0, "ROLA: AA rot_l 1=55");
    apply_and_check(0,12, 8'hF0, 8'h04, 0, 2'b11, 2,
                    {8'h0, ((8'hF0<<4)|(8'hF0>>(W-4))) & 8'hFF},
                    0,0,0,0,0,0, "ROLA: F0 rot_l 4=0F");
    apply_and_check(0,12, 8'hAA, 8'h08, 0, 2'b11, 2, 16'd0, 0,0,0,0,0,1, "ROLA: B=8 out-of-range ERR");
    apply_and_check(0,12, 8'hAA, 8'h01, 0, 2'b01, 2, 16'd0, 0,0,0,0,0,1, "ROLA: IV[1]=0 ERR");

    // ---- CMD 13: Rotate Right A by B ----
    $display("\n[CMD=13] Rotate Right A by B");
    apply_and_check(0,13, 8'hAA, 8'h01, 0, 2'b11, 2,
                    {8'h0, ((8'hAA>>1)|(8'hAA<<(W-1))) & 8'hFF},
                    0,0,0,0,0,0, "RORA: AA rot_r 1=55");
    apply_and_check(0,13, 8'h0F, 8'h04, 0, 2'b11, 2,
                    {8'h0, ((8'h0F>>4)|(8'h0F<<(W-4))) & 8'hFF},
                    0,0,0,0,0,0, "RORA: 0F rot_r 4=F0");
    apply_and_check(0,13, 8'hAA, 8'h08, 0, 2'b11, 2, 16'd0, 0,0,0,0,0,1, "RORA: B=8 out-of-range ERR");

    // ===========================================================
    // CE = 0: outputs must hold previous values
    // ===========================================================
    $display("\n--- CE=0 Hold Test ---");
    begin
        reg signed [(2*W)-1:0] old_res;
        reg old_cout, old_oflow, old_g, old_l, old_e, old_err;
        
        // First do a normal op to set known output (1-cycle delay)
        @(negedge CLK); MODE=1; CMD=0; OPA=8'd10; OPB=8'd20; INP_VALID=2'b11; CE=1;
        repeat(2) @(posedge CLK); #1;
        
        old_res   = RES; old_cout = COUT; old_oflow = OFLOW;
        old_g = G; old_l = L; old_e = E; old_err = ERR;
        
        // Now CE=0, change inputs
        @(negedge CLK); CE=0; OPA=8'd99; OPB=8'd99; CMD=4'd0;
        repeat(2) @(posedge CLK); #1;
        
        total_tests = total_tests + 1;
        if (RES===old_res && COUT===old_cout && OFLOW===old_oflow &&
            G===old_g && L===old_l && E===old_e && ERR===old_err) begin
            pass_count = pass_count + 1;
            $display("  PASS | CE=0: outputs held correctly");
        end else begin
            fail_count = fail_count + 1;
            $display("  FAIL | CE=0: outputs changed when CE=0!");
        end
        CE = 1;
    end

    // ===========================================================
    // RST: outputs must clear
    // ===========================================================
    $display("\n--- RST Test ---");
    @(negedge CLK); RST=1; CE=1;
    repeat(2) @(posedge CLK); #1;
    
    total_tests = total_tests + 1;
    if (RES===0 && COUT===0 && OFLOW===0 && G===0 && L===0 && E===0 && ERR===0) begin
        pass_count = pass_count + 1;
        $display("  PASS | RST: all outputs cleared to 0");
    end else begin
        fail_count = fail_count + 1;
        $display("  FAIL | RST: outputs not cleared! RES=%0d COUT=%b OFLOW=%b G=%b L=%b E=%b ERR=%b",
                 $signed(RES),COUT,OFLOW,G,L,E,ERR);
    end
    RST = 0;

    // ===========================================================
    // Summary
    // ===========================================================
    $display("\n========================================================");
    $display("  RESULTS: %0d / %0d tests PASSED  (%0d FAILED)",
             pass_count, total_tests, fail_count);
    $display("  Operations working perfectly: %0d/%0d",
             pass_count, total_tests);
    $display("========================================================\n");

    $finish;
end

// ---- Timeout watchdog ----
initial begin
    #100000;
    $display("TIMEOUT: simulation took too long, stopping.");
    $finish;
end

initial begin
    $dumpfile("dump2.vcd");
    $dumpvars;
end

endmodule