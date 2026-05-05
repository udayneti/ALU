`include "ALU.v"

`define WIDTH 8
`define VALID_M 2
`define OPERATION 4

module tb;
    reg CLK;
    reg RST;
    reg [`VALID_M-1:0] INP_VALID;
	reg  MODE;
    reg [`OPERATION-1:0] CMD;
	reg CE;
    reg [`WIDTH-1:0] OPA;
    reg [`WIDTH-1:0] OPB;
    reg CIN;
    wire ERR;
    wire [2*`WIDTH-1:0] RES;
	wire OFLOW;
	wire COUT;
	wire G;
	wire L;
	wire E;
    integer i;
 
  ALU dut(CLK,RST,INP_VALID,MODE,CMD,CE,OPA,OPB,CIN, ERR, RES,OFLOW,COUT,G,L,E);
 
 
  initial begin
    CLK=1'b0;
    forever #5 CLK=~CLK;
  end
 
  task arithmetic_inputs;
  begin
    MODE = 1'b1;
    CE=1'b1;
    RST = 1'b0;
    INP_VALID = 2'b11;
    OPA = 10;
    OPB = 5;
    @(posedge CLK);
    for(i=0;i<14;i=i+1) begin
        // OPA = $urandom();
        // OPB = $urandom();
        CMD = i;
        CIN = 1;
        @(posedge CLK);
        if(i == 9) begin
            OPA = 4;
            OPB = 5;
            @(posedge CLK);
            @(posedge CLK); 
        end else if(i == 10) begin
          OPA = 10;
          OPB = 3;
          @(posedge CLK);
          @(posedge CLK);
        end
    end
  end
  endtask
 
   task logic_inputs;
   begin
    MODE = 1'b0;
    CE=1'b1;
    RST = 1'b0;
    INP_VALID = 2'b11;
 
    for(i=0;i<14;i=i+1) begin
//       OPA = $urandom();
      OPA = 10;
//       OPB = $urandom();
      OPB = 5;
      CMD = i;
      CIN = 1;
      @(posedge CLK);
    end
 end
  endtask
 
  task reset;
  begin
    RST=1'b1;
    repeat(2)
      @(posedge CLK);
 
    RST=1'b0;
  end
  endtask
 
  initial begin
    reset;
    arithmetic_inputs;
    logic_inputs;
    repeat(3)
      @(posedge CLK);
    $finish;
  end
 
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
  end
 
endmodule