`default_nettype none                                              
                                               
module ALU #(                                                      
    parameter W = 8,                                               
    parameter CMDWD = 4                                            
) (                                                                
    CLK, RST, INP_VALID, MODE, CMD, CE, OPA, OPB, CIN, ERR, RES, OFLOW, COUT, G, L, E
);

localparam RW = $clog2(W);
                                                                   
input wire RST;
input wire CLK;
input wire CE;
input wire MODE;
input wire CIN;                                   
input wire signed [W-1:0] OPA, OPB;
input wire [CMDWD-1:0] CMD;
input wire [1:0] INP_VALID;
output reg signed [(2*W)-1:0] RES;
output reg COUT;
output reg OFLOW;
output reg G, L, E;
output reg ERR;
                                                                   
reg signed [(2*W)-1:0] res;                                        
reg                 cout, oflow;                                   
reg                 g, l, e;                                       
reg                 err;                                           
reg                 C;
reg [1:0]           IV;                       
reg [W-1:0]         A, B;                                   
reg signed [W-1:0]  SA, SB;

reg mul_done;
                                                                   
always @(posedge CLK or posedge RST) begin                         
    if(RST) begin                                                  
        RES         <= 0;
        COUT        <= 0;
        OFLOW       <= 0;
        {G, L, E}   <= 0;
        ERR         <= 0;
        A           <= 0;
        B           <= 0;
        C           <= 0;
        SA          <= 0;
        SB          <= 0;
    end else begin
      	A           <= OPA;
        B           <= OPB;
        C           <= CIN;
        IV          <= INP_VALID;
        SA          <= OPA;
        SB          <= OPB;
      if(CE) begin
        RES         <= res;
        COUT        <= cout;
        OFLOW       <= oflow;
        ERR         <= err;
        {G, L, E}   <= {g, l, e};
      end
    end
end

always @(*) begin
    res = 0;
    cout = 0;
    oflow = cout;
    err = 0;
    {g, l, e} = 0;
  if(MODE) begin
        case(CMD)
            0: begin
                {res[W:0], err} = (IV == 2'b11) ? {A + B, 1'b0} : 1;
                cout = res[W];
            end
            1: begin
                {res[W:0], err} = (IV == 2'b11) ? {A - B, 1'b0} : 1;
                cout = res[W];
            end
            2: begin
                {res[W:0], err} = (IV == 2'b11) ? {A + B + C, 1'b0} : 1;
                cout = res[W];
            end
            3: begin
                {res[W:0], err} = (IV == 2'b11) ? {A - B - C, 1'b0} : 1;
                cout = res[W];
            end
            4: begin
                {res[W:0], err} = (IV[0] == 1'b1) ? {A + 1'b1, 1'b0} : 1;
                cout = res[W];
            end
            5: begin
                {res[W:0], err} = (IV[0] == 1'b1) ? {A - 1'b1, 1'b0} : 1;
                cout = res[W];
            end
            6: begin
                {res[W:0], err} = (IV[1] == 1'b1) ? {B + 1'b1, 1'b0} : 1;
                cout = res[W];
            end
            7: begin
                {res[W:0], err} = (IV[1] == 1'b1) ? {B - 1'b1, 1'b0} : 1;
                cout = res[W];
            end
            8: begin
                {g, l, e, err}  = (IV == 2'b11) ? {A > B, A < B, A == B, 1'b0} : 1;
            end
            9: begin
                {res[W:0], err} = (IV == 2'b11) ? {(A + 1'b1) * (B + 1'b1), 1'b0} : 1;
                cout = res[W];
            end
            10: begin
                {res[W:0], err} = (IV == 2'b11) ? {(A << 1'b1) * B, 1'b0} : 1;
                cout = res[W];
            end
            11: begin
                if(IV == 2'b11) begin
                    res[W:0] = SA + SB;
                    cout = res[W];
                    {g, l, e}  = {SA > SB, SA < SB, SA == SB};
                    oflow = (~SA[W-1] & ~SB[W-1] & res[W-1]) | (SA[W-1] & SA[W-1] & ~res[W-1]);
                end else begin
                    {cout, res, g, l, e, oflow, err} = 1;
                end
            end
            12: begin
                if(IV == 2'b11) begin
                  res[W:0] = SA - SB;
                  cout = res[W];
                  {g, l, e} = {SA > SB, SA < SB, SA == SB};
                  oflow = (SA[W-1] ^ SB[W-1]) & (res[W-1] ^ SA[W-1]);
                end else begin
                  {cout, res, g, l, e, oflow, err} = 1;
                end
            end
            default: res = 0;
        endcase
    end else begin
        case(CMD)
            0: begin
                {res, err} = (IV == 2'b11) ? {A & B, 1'b0} : 1;
            end
            1: begin
                {res, err} = (IV == 2'b11) ? {~(A & B), 1'b0} : 1;
            end
            2: begin
                {res, err} = (IV == 2'b11) ? {A | B, 1'b0} : 1;
            end
            3: begin
                {res, err} = (IV == 2'b11) ? {~(A | B), 1'b0} : 1;
            end
            4: begin
                {res, err} = (IV == 2'b11) ? {A ^ B, 1'b0} : 1;
            end
            5: begin
                {res, err} = (IV == 2'b11) ? {~(A ^ B), 1'b0} : 1;
            end
            6: begin
                {res, err} = (IV[0] == 1'b1) ? {~A, 1'b0} : 1;
            end
            7: begin
                {res, err} = (IV[1] == 1'b1) ? {~B, 1'b0} : 1;
            end
            8: begin
                {res, err} = (IV[0] == 1'b1) ? {A >> 1, 1'b0} : 1;
            end
            9: begin
                {res, err} = (IV[0] == 1'b1) ? {A << 1, 1'b0} : 1;
            end
            10: begin
                {res, err} = (IV[1] == 1'b1) ? {B >> 1, 1'b0} : 1;
            end
            11: begin
                {res, err} = (IV[1] == 1'b1) ? {B << 1, 1'b0} : 1;
            end
            12: begin
                if(IV == 2'b11 && ~|B[W-1:RW]) begin
                    res = (A << B[RW-1:0] | A >> (W - B[RW-1:0])) & {W{1'b1}};
                    // res = ({A, A} << B[RW-1:0]) >> W;
                end else begin
                  {res, err} = 1;
                end
            end
            13: begin
                if(IV == 2'b11 && ~|B[W-1:RW]) begin
                    res = (A >> B[RW-1:0] | A << (W - B[RW-1:0])) & {W{1'b1}};
                    // res = {A, A} >> B[RW-1:0];
                end else begin
                  {res, err} = 1;
                end
            end
            default: res = 0;
        endcase
    end
end
endmodule