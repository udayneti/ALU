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
reg [CMDWD-1:0]     CMDR;
reg [W-1:0]         A, B;
reg [1:0]           IV;
reg                 C;
reg                 MODER;
reg                 cout, oflow, g, l, e, err;

reg [1:0] mul_state;

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
        CMDR        <= 0;
        MODER       <= 0;
        IV          <= 0;
        mul_state   <= 0;
    end else if(CE) begin

        if (mul_state == 2'd1 && MODE == 1'b1 && (CMD == 4'd9 || CMD == 4'd10) && CMD == CMDR) begin
        // Do Nothing during middle cycle of multiplication operation
        end else begin
            A           <= OPA;
            B           <= OPB;
            C           <= CIN;
            IV          <= INP_VALID;
            CMDR        <= CMD;
            MODER       <= MODE;
        end

        if(MODE == 1'b1 && (CMD == 4'd9 || CMD == 4'd10)) begin
            if(mul_state == 2'd1 && CMD == CMDR && MODE == MODER) begin
                mul_state <= 2'd2;
            end else begin
                mul_state <= 2'd1;
            end
        end else begin
            mul_state <= 2'd0;
        end
      
        RES         <= res;
        COUT        <= cout;
        OFLOW       <= oflow;
        ERR         <= err;
        {G, L, E}   <= {g, l, e};

      end else begin
        RES         <= RES;
        COUT        <= COUT;
        OFLOW       <= OFLOW;
        ERR         <= ERR;
        {G, L, E}   <= {G, L, E};
      end
end

always @(*) begin
    res = 0;
    cout = 0;
    oflow = cout;
    err = 0;
    {g, l, e} = 0;
  if(MODER) begin
        case(CMDR)
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
                    res[W:0] = $signed(A) + $signed(B);
                    {g, l, e}  = {$signed(A) > $signed(B), $signed(A) < $signed(B), A == B};
                    oflow = (~A[W-1] & ~B[W-1] & res[W-1]) | (A[W-1] & B[W-1] & ~res[W-1]);
                end else begin
                    {cout, res, g, l, e, oflow, err} = 1;
                end
            end
            12: begin
                if(IV == 2'b11) begin
                  res[W:0] = $signed(A) - $signed(B);
                  {g, l, e} = {$signed(A) > $signed(B), $signed(A) < $signed(B), A == B};
                  oflow = (A[W-1] ^ B[W-1]) & (res[W-1] ^ A[W-1]);
                end else begin
                  {cout, res, g, l, e, oflow, err} = 1;
                end
            end
            default: res = 0;
        endcase
    end else begin
        case(CMDR)
             0: {res, err} = (IV   == 2'b11) ? {A & B, 1'b0} : 1;
             1: {res, err} = (IV   == 2'b11) ? {~(A & B), 1'b0} : 1;
             2: {res, err} = (IV   == 2'b11) ? {A | B, 1'b0} : 1;
             3: {res, err} = (IV   == 2'b11) ? {~(A | B), 1'b0} : 1;
             4: {res, err} = (IV   == 2'b11) ? {A ^ B, 1'b0} : 1;
             5: {res, err} = (IV   == 2'b11) ? {~(A ^ B), 1'b0} : 1;
             6: {res, err} = (IV[0] == 1'b1) ? {~A, 1'b0} : 1;
             7: {res, err} = (IV[1] == 1'b1) ? {~B, 1'b0} : 1;
             8: {res, err} = (IV[0] == 1'b1) ? {A >> 1, 1'b0} : 1;
             9: {res, err} = (IV[0] == 1'b1) ? {A << 1, 1'b0} : 1;
            10: {res, err} = (IV[1] == 1'b1) ? {B >> 1, 1'b0} : 1;
            11: {res, err} = (IV[1] == 1'b1) ? {B << 1, 1'b0} : 1;
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