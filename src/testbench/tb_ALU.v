`include "../design/ALU.v"

`define PASS 1'b1
`define FAIL 1'b0
`define no_of_testcases 134
`define W 8
`define CW 4
`define RW $clog2(`W)

module tb_ALU;
    reg [54:0] curr_test_case = 55'b0;
    reg [54:0] stimulus_mem [0:`no_of_testcases-1];
    reg [76:0] response_packet;

    integer i, j;
    reg CLK, RST, CE;

    reg [7:0] Feature_Id;
    reg [1:0] INP_VALID;
    reg [`W-1:0] OPA, OPB;
    reg [`CW-1:0] CMD;
    reg CIN, MODE;

    reg [(2*`W)-1:0] ERES;
    reg ECOUT, EOFLOW, EG, EL, EE, EERR;

    wire [(2*`W)-1:0] RES;
    wire COUT, OFLOW, G, L, E, ERR;

    // -------------------------------------------------------------------------
    // Reference Model
    // -------------------------------------------------------------------------
    function automatic [((2*`W)-1 + 6): 0] reference_model;
        input Mode, Cin;
        input [`W-1:0] A, B;
        input [`CW-1:0] Cmd;
        input [1:0] IValid;
        reg [(2*`W)-1:0] Res;
        reg Cout, Oflow, g, l, e, Err;
        begin
            Res = 0;
            Cout = 0;
            Oflow = 0;
            g = 0;
            l = 0;
            e = 0;
            Err = 0;
            if(Mode) begin
                case(Cmd)
                0: if(IValid == 2'b11) begin Res = A + B; Err = 1'b0; Cout = Res[`W]; end else begin Err = 1'b1; end
                1: if(IValid == 2'b11) begin Res = A - B; Err = 1'b0; Oflow = Res[`W]; end else begin Err = 1'b1; end
                2: if(IValid == 2'b11) begin Res = A + B + Cin; Err = 1'b0; Cout = Res[`W]; end else begin Err = 1'b1; end
                3: if(IValid == 2'b11) begin Res = A - B - Cin; Err = 1'b0; Oflow = Res[`W]; end else begin Err = 1'b1; end
                4: if(IValid[0] == 1'b1) begin Res = A + 1'b1; Err = 1'b0; end else begin Err = 1'b1; end
                5: if(IValid[0] == 1'b1) begin Res = A - 1'b1; Err = 1'b0; end else begin Err = 1'b1; end
                6: if(IValid[1] == 1'b1) begin Res = B + 1'b1; Err = 1'b0; end else begin Err = 1'b1; end
                7: if(IValid[1] == 1'b1) begin Res = B - 1'b1; Err = 1'b0; end else begin Err = 1'b1; end
                8: if(IValid == 2'b11) begin g = A > B; l = A < B; e = A == B; Err = 1'b0; end else begin Err = 1'b1; end
                9: if(IValid == 2'b11) begin Res = (A + 1'b1) * (B + 1'b1); Err = 1'b0; end else begin Err = 1'b1; end
                10: if(IValid == 2'b11) begin Res = (A << 1'b1) * B; Err = 0; end else begin Err = 1'b1; end
                4'd11: begin
                        if (IValid == 2'b11) begin
                            Res = $signed(A) + $signed(B);
                            Oflow = (A[`W-1] == B[`W-1]) && (Res[`W-1] != A[`W-1]) ? 1'b1 : 1'b0;
                            {g, l, e} = ($signed(A) > $signed(B)) ? 3'b100 : ($signed(A) < $signed(B)) ? 3'b010 : 3'b001;
                        end else begin
                            Err = 1;
                        end
                    end
                4'd12: begin
                        if (IValid == 2'b11) begin
                            Res = $signed(A) - $signed(B);
                            Oflow = (A[`W-1] != B[`W-1]) && (Res[`W-1] != A[`W-1]) ? 1'b1 : 1'b0;
                            {g, l, e} = ($signed(A) > $signed(B)) ? 3'b100 : ($signed(A) < $signed(B)) ? 3'b010 : 3'b001;
                        end else begin
                            Err = 1;
                        end
                    end
                default: begin
                    Err = 1;
                end
                endcase
            end else begin
                case(Cmd)
                4'd0: begin 
                    {Res[`W-1:0], Err} = (IValid == 2'b11) ? {A & B, 1'b0} : 1; // AND
                    end
                4'd1: begin 
                    {Res[`W-1:0], Err} = (IValid == 2'b11) ? {~(A & B), 1'b0} : 1; // NAND
                    end
                4'd2: begin
                    {Res[`W-1:0], Err} = (IValid == 2'b11) ? {A | B, 1'b0} : 1; // OR
                    end
                4'd3: begin
                    {Res[`W-1:0], Err} = (IValid == 2'b11) ? {~(A | B), 1'b0} : 1; // NOR
                    end
                4'd4: begin
                    {Res[`W-1:0], Err} = (IValid == 2'b11) ? {A ^ B, 1'b0} : 1; // XOR
                    end
                4'd5: begin
                    {Res[`W-1:0], Err} = (IValid == 2'b11) ? {~(A ^ B), 1'b0} : 1; // XNOR
                    end
                4'd6: begin
                    {Res[`W-1:0], Err} = (IValid[0] == 1'b1) ? {~A, 1'b0} : 1; // NOTA
                    end
                4'd7: begin
                    {Res[`W-1:0], Err} = (IValid[1] == 1'b1) ? {~B, 1'b0} : 1; // NOTB
                    end
                4'd8: begin
                    {Res[`W-1:0], Err} = (IValid[0] == 1'b1) ? {A >> 1'b1, 1'b0} : 1; // SHRA1
                    end
                4'd9: begin
                    {Res[`W-1:0], Err} = (IValid[0] == 1'b1) ? {A << 1'b1, 1'b0} : 1; // SHLA1
                    end
                4'd10: begin
                    {Res[`W-1:0], Err} = (IValid[1] == 1'b1) ? {B >> 1'b1, 1'b0} : 1; // SHRB1
                    end
                4'd11: begin
                    {Res[`W-1:0], Err} = (IValid[1] == 1'b1) ? {B << 1'b1, 1'b0} : 1; // SHLB1
                    end
                4'd12: begin
                    if (IValid == 2'b11) begin
                        Err = (~|B[`W-1:`RW]) ? 0 : 1;
                        Res[`W-1:0] = ({A, A} << B[`RW-1:0]) >> `W;
                    end else begin
                        Err = 1;
                    end
                end
                4'd13: begin
                    if (IValid == 2'b11) begin
                        Err = (~|B[`W-1:`RW]) ? 0 : 1;
                        Res[`W-1:0] = ({A, A} >> B[`RW-1:0]);
                    end else begin
                        Err = 1;
                    end
                end
                default: Err = 1;
                endcase
            end
            reference_model = {Res, Cout, Oflow, g, l, e, Err};
        end
        
    endfunction

    // -------------------------------------------------------------------------
    // Tasks
    // -------------------------------------------------------------------------
    task read_stimulus();
        begin
            #10 $readmemb("stimulus.txt", stimulus_mem); 
        end
    endtask

    ALU dut(
        .CLK(CLK), .RST(RST), .CE(CE), .MODE(MODE), .CIN(CIN),
        .OPA(OPA), .OPB(OPB), .CMD(CMD), .INP_VALID(INP_VALID),
        .RES(RES), .COUT(COUT), .OFLOW(OFLOW),
        .G(G), .L(L), .E(E), .ERR(ERR)
    );

    integer stim_mem_ptr = 0, stim_stimulus_mem_ptr = 0;
    integer file_id;

    initial begin
        CLK = 0;
        forever #5 CLK = ~CLK;
    end

    task dut_reset ();
        begin 
        CE=1;
        #10 RST=1;
        #20 RST=0;
        end
    endtask

    task global_init ();
        begin
        curr_test_case=55'b0;
        response_packet=77'b0;
        stim_mem_ptr=0;
        end
    endtask 

    task sanity_tests();
        begin
            $display("\n=======================================================");
            $display("--- Starting Sanity & Control Signal Tests (1-8) ---");
            $display("=======================================================");
            
            // Feature 1: CLK toggle is naturally tested by the progression of this task.

            // Feature 5 & 8: CE Enable & Parameterized Width (OPA=FF, OPB=FF)
            @(negedge CLK);
            CE = 1; MODE = 1; CMD = 0; OPA = 16'hFFFF; OPB = 16'hFFFF; INP_VALID = 2'b11; CIN = 0;
            @(posedge CLK); // Cycle 0: Capture
            @(posedge CLK); // Cycle 1: Compute
            #1; // Settle
            if (RES === 16'h01FE && COUT === 1'b1 && ERR === 1'b0)
                $display("[PASS] Feat 5/8: CE Enable & Max Width (OPA=FF, OPB=FF -> 01FE)");
            else
                $display("[FAIL] Feat 5/8: Expected RES=01FE COUT=1, Got RES=%h COUT=%b", RES, COUT);
            
            // Feature 6: CE Hold Outputs
            @(negedge CLK);
            CE = 0;                   // Disable clock enable
            OPA = 8'hAA; OPB = 8'h55; // Change inputs
            @(posedge CLK); 
            @(posedge CLK); 
            #1;
            if (RES === 16'h01FE && COUT === 1'b1) 
                $display("[PASS] Feat 6: CE Hold Outputs (Outputs frozen at 01FE when CE=0)");
            else
                $display("[FAIL] Feat 6: CE Hold failed. Outputs changed to RES=%h", RES);

            // Feature 2: Asynchronous Reset Assert
            #2; // Trigger reset arbitrarily mid-cycle
            RST = 1; 
            #1; // Async reset propagation delay
            if (RES === 16'h0000 && COUT === 1'b0 && ERR === 1'b0)
                $display("[PASS] Feat 2: Asynchronous Reset (Outputs instantly zeroed)");
            else
                $display("[FAIL] Feat 2: Asynchronous Reset failed. RES=%h", RES);
            
            // Feature 4: Async Reset Deassert & Resume
            @(negedge CLK);
            RST = 0;
            CE = 1; MODE = 1; CMD = 1; OPA = 8'h50; OPB = 8'h1E; INP_VALID = 2'b11; // SUB 80-30=50
            @(posedge CLK); // Capture
            @(posedge CLK); // Compute
            #1;
            if (RES === 16'h0032 && ERR === 1'b0)
                $display("[PASS] Feat 4: Reset Deassert (Resumes normal operation, RES=0032)");
            else
                $display("[FAIL] Feat 4: Reset Deassert failed. RES=%h", RES);

            // Feature 3: Reset during operation
            @(negedge CLK);
            OPA = 8'h64; OPB = 8'h32; // Change inputs
            @(posedge CLK);           // Capture occurs
            #2;                       // Wait a fraction before the compute posedge
            RST = 1;                  // Assert reset mid-operation
            #1;
            if (RES === 16'h0000)
                $display("[PASS] Feat 3: Reset during operation (Operation safely aborted)");
            else
                $display("[FAIL] Feat 3: Reset during operation failed. RES=%h", RES);
            
            // Feature 7: RST Priority over CE
            @(negedge CLK);
            RST = 1; CE = 1;          // Both asserted
            OPA = 8'h10; OPB = 8'h10; CMD = 0;
            @(posedge CLK);
            @(posedge CLK);
            #1;
            if (RES === 16'h0000)
                $display("[PASS] Feat 7: RST Priority over CE (RST wins -> Outputs=0)");
            else
                $display("[FAIL] Feat 7: RST Priority failed. RES=%h", RES);
            
            @(negedge CLK);
            RST = 0;
            CE = 1;
            $display("=======================================================\n");
        end
    endtask

    task driver();
        begin
            @(negedge CLK);
            
            curr_test_case = stimulus_mem[stim_mem_ptr];
            stim_mem_ptr = stim_mem_ptr + 1;

            Feature_Id = curr_test_case[54:47];
            INP_VALID  = curr_test_case[46:45];
            OPA        = curr_test_case[44:37];
            OPB        = curr_test_case[36:29];
            CMD        = curr_test_case[28:25];
            CIN        = curr_test_case[24];
            CE         = curr_test_case[23];
            MODE       = curr_test_case[22];
            
            @(posedge CLK);
            
            if (MODE == 1'b1 && (CMD == 4'd9 || CMD == 4'd10)) begin
                @(posedge CLK);
            end
        end
    endtask

    task automatic monitor();
        reg mode;
        reg [3:0] cmd;
        reg [7:0] feature_id;
        reg [(2*`W)-1 + 6:0] expected_data, exact_data;
        reg [(2*`W)-1 + 9:0] inputs;
        begin
            // Wait for DUT to latch inputs and process
            @(negedge CLK);
            #1;
            mode = MODE;
            cmd = CMD;
            feature_id = Feature_Id;
            inputs = {OPA, OPB, CMD, MODE, INP_VALID, CIN, CE};
            {ERES, ECOUT, EOFLOW, EG, EL, EE, EERR} = reference_model(MODE, CIN, OPA, OPB, CMD, INP_VALID);
            expected_data = {ERES, ECOUT, EOFLOW, EG, EL, EE, EERR};
            @(posedge CLK);
            @(posedge CLK);
           // Wait an extra cycle for 2-cycle latency multipliers
            if (mode == 1'b1 && (cmd == 4'd9 || cmd == 4'd10)) begin
                @(posedge CLK);
            end
            #1;
            exact_data = {RES, COUT, OFLOW, G, L, E, ERR};
            score_board(feature_id, inputs, expected_data, exact_data);
            response_packet[54:0]    = curr_test_case;
            response_packet[55]      = ERR;
            response_packet[56]      = OFLOW;
            response_packet[59:57]   = {G, L, E};
            response_packet[60]      = COUT;
            response_packet[76:61]   = RES;
            
        end
    endtask

    reg [8:0] scb_stimulus_mem [0:`no_of_testcases-1];

    task score_board(input [7:0] feature_id, input [(2*`W)-1 + 9:0] inputs, input [(2*`W)-1 + 6:0] expd, input [(2*`W)-1 + 6:0] excd);
        begin
            #1; // Minor evaluation delay
            if(expd === excd) begin
                scb_stimulus_mem[stim_stimulus_mem_ptr] = {feature_id, `PASS};
                $display("[PASS] Time: %0t | Feat_ID: %0d", $time, feature_id);
                $display("       INP: OPA=%h OPB=%h CMD=%b MODE=%b INP_VALID=%b CIN=%b", inputs[(5 + `CW + `W) +:`W], inputs[(5+`CW) +:`W], inputs[5+:`CW], inputs[4], inputs[3:2], inputs[1]);
                $display("       EXP: RES=%h COUT=%b OFL=%b G=%b L=%b E=%b ERR=%b", expd[21:6], expd[5], expd[4], expd[3], expd[2], expd[1], expd[0]);
                $display("       GOT: RES=%h COUT=%b OFL=%b G=%b L=%b E=%b ERR=%b", excd[21:6], excd[5], excd[4], excd[3], excd[2], excd[1], excd[0]);
            end
            else begin
                scb_stimulus_mem[stim_stimulus_mem_ptr] = {feature_id, `FAIL};
                $display("[FAIL] Time: %0t | Feat_ID: %0d", $time, feature_id);
                $display("       INP: OPA=%h OPB=%h CMD=%b MODE=%b INP_VALID=%b CIN=%b", inputs[(5 + `CW + `W) +:`W], inputs[(5+`CW) +:`W], inputs[5+:`CW], inputs[4], inputs[3:2], inputs[1]);
                $display("       EXP: RES=%h COUT=%b OFL=%b G=%b L=%b E=%b ERR=%b", expd[21:6], expd[5], expd[4], expd[3], expd[2], expd[1], expd[0]);
                $display("       GOT: RES=%h COUT=%b OFL=%b G=%b L=%b E=%b ERR=%b", excd[21:6], excd[5], excd[4], excd[3], excd[2], excd[1], excd[0]);
            end
            stim_stimulus_mem_ptr = stim_stimulus_mem_ptr + 1;
        end
    endtask

    task gen_report;
        integer pointer;
        reg [55:0] status;
        begin
            file_id = $fopen("results.txt", "w");
            for(pointer = 0; pointer <= stim_stimulus_mem_ptr-1; pointer = pointer+1 ) begin 
                status = scb_stimulus_mem[pointer];
                if(status[0]) begin
                    $fdisplay(file_id, "Feature ID %8d : PASS", status[8:1]);
                    // $fdisplay(file_id, "       INP: CE=%b INP_VALID=%b CIN=%b MODE=%b CMD=%b OPA=%h OPB=%h", CE, INP_VALID, CIN, MODE, CMD, OPA, OPB);
                    // $fdisplay(file_id, "       EXP: RES=%h COUT=%b OFL=%b G=%b L=%b E=%b ERR=%b", ERES, ECOUT, EOFLOW, EG, EL, EE, EERR);
                    // $fdisplay(file_id, "       GOT: RES=%h COUT=%b OFL=%b G=%b L=%b E=%b ERR=%b", RES, COUT, OFLOW, G, L, E, ERR);
                end else begin
                    $fdisplay(file_id, "Feature ID %8d : FAIL", status[8:1]);
                    // $fdisplay(file_id, "       INP: CE=%b INP_VALID=%b CIN=%b MODE=%b CMD=%b OPA=%h OPB=%h", CE, INP_VALID, CIN, MODE, CMD, OPA, OPB);
                    // $fdisplay(file_id, "       EXP: RES=%h COUT=%b OFL=%b G=%b L=%b E=%b ERR=%b", ERES, ECOUT, EOFLOW, EG, EL, EE, EERR);
                    // $fdisplay(file_id, "       GOT: RES=%h COUT=%b OFL=%b G=%b L=%b E=%b ERR=%b", RES, COUT, OFLOW, G, L, E, ERR);
                end
            end            
            $fclose(file_id);
        end   
    endtask

    // -------------------------------------------------------------------------
    // Main Test Sequence
    // -------------------------------------------------------------------------
    initial begin 
        $dumpfile("tb_alu.vcd");
        $dumpvars(0, tb_ALU);

        #10;
        global_init();
        dut_reset();
        sanity_tests();
        read_stimulus();
        
        // Removed the fork...join to force sequential Driver -> Monitor execution
        for(j=0; j<=`no_of_testcases-1; j=j+1) begin
            // If we hit an uninitialized memory slot (x), break the loop early
            if (stimulus_mem[j] === 55'bx) begin
                $display("End of valid stimulus reached at index %0d. Breaking loop.", j);
                j = `no_of_testcases;
            end else begin 
            fork
                driver();
                monitor();
            join_any;
            end
        end
        
        gen_report();
        #20 $display("Simulation Complete. Check results.txt");
        #10 $finish();
    end
endmodule
