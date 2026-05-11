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
        if(MODE == 1'b1 && (CMD == 4'd9 || CMD == 4'd10)) begin
            if(mul_state == 2'd1 && CMD == CMDR && MODE == MODER) begin
                mul_state <= 2'd2;
            end else begin
                mul_state <= 2'd1;
            end
        end else begin
            mul_state <= 2'd0;
        end

        if (mul_state == 2'd1 && MODE == 1'b1 && (CMD == 4'd9 || CMD == 4'd10) && CMD == CMDR) begin
            A           <= A;
            B           <= B;
            C           <= C;
            IV          <= IV;
            CMDR        <= CMDR;
            MODER       <= MODER;
            RES         <= 0;
            COUT        <= 0;
            OFLOW       <= 0;
            ERR         <= 1;
            {G, L, E}   <= 0;
        end else begin
            A           <= OPA;
            B           <= OPB;
            C           <= CIN;
            IV          <= INP_VALID;
            CMDR        <= CMD;
            MODER       <= MODE;
            RES         <= res;
            COUT        <= cout;
            OFLOW       <= oflow;
            ERR         <= err;
            {G, L, E}   <= {g, l, e};
        end
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
    oflow = 0;
    err = 0;
    {g, l, e} = 0;
  if(MODER) begin
        case(CMDR)
            0: if(IV == 2'b11) begin res = A + B; err = 1'b0; cout = res[W]; end else begin err = 1'b1; end
            1: if(IV == 2'b11) begin res = A - B; err = 1'b0; oflow = res[W]; end else begin err = 1'b1; end
            2: if(IV == 2'b11) begin res = A + B + C; err = 1'b0; cout = res[W]; end else begin err = 1'b1; end
            3: if(IV == 2'b11) begin res = A - B - C; err = 1'b0; oflow = res[W]; end else begin err = 1'b1; end
            4: if(IV[0] == 1'b1) begin res = A + 1'b1; err = 1'b0; end else begin err = 1'b1; end
            5: if(IV[0] == 1'b1) begin res = A - 1'b1; err = 1'b0; end else begin err = 1'b1; end
            6: if(IV[1] == 1'b1) begin res = B + 1'b1; err = 1'b0; end else begin err = 1'b1; end
            7: if(IV[1] == 1'b1) begin res = B - 1'b1; err = 1'b0; end else begin err = 1'b1; end
            8: if(IV == 2'b11) begin g = A > B; l = A < B; e = A == B; err = 1'b0; end else begin err = 1'b1; end
            9: if(IV == 2'b11) begin res = (A + 1'b1) * (B + 1'b1); err = 1'b0; end else begin err = 1'b1; end
            10: if(IV == 2'b11) begin res = (A << 1'b1) * B; err = 0; end else begin err = 1'b1; end
            11: begin
                if(IV == 2'b11) begin
                    res = $signed(A) + $signed(B);
                    {g, l, e}  = {$signed(A) > $signed(B), $signed(A) < $signed(B), A == B};
                    oflow = (~A[W-1] & ~B[W-1] & res[W-1]) | (A[W-1] & B[W-1] & ~res[W-1]);
                end else begin
                    err = 1;
                end
            end
            12: begin
                if(IV == 2'b11) begin
                    res = $signed(A) - $signed(B);
                    {g, l, e} = {$signed(A) > $signed(B), $signed(A) < $signed(B), A == B};
                    oflow = (A[W-1] ^ B[W-1]) & (res[W-1] ^ A[W-1]);
                end else begin
                    err = 1;
                end
            end
            default: err = 1;
        endcase
    end else begin
        case(CMDR)
             0: {res, err} = (IV   == 2'b11) ? {{W{1'b0}}, A & B,    1'b0} : 1;
             1: {res, err} = (IV   == 2'b11) ? {{W{1'b0}}, ~(A & B), 1'b0} : 1;
             2: {res, err} = (IV   == 2'b11) ? {{W{1'b0}}, A | B,    1'b0} : 1;
             3: {res, err} = (IV   == 2'b11) ? {{W{1'b0}}, ~(A | B), 1'b0} : 1;
             4: {res, err} = (IV   == 2'b11) ? {{W{1'b0}}, A ^ B,    1'b0} : 1;
             5: {res, err} = (IV   == 2'b11) ? {{W{1'b0}}, ~(A ^ B), 1'b0} : 1;
             6: {res, err} = (IV[0] == 1'b1) ? {{W{1'b0}}, ~A,       1'b0} : 1;
             7: {res, err} = (IV[1] == 1'b1) ? {{W{1'b0}}, ~B,       1'b0} : 1;
             8: {res, err} = (IV[0] == 1'b1) ? {{W{1'b0}}, A >> 1,   1'b0} : 1;
             9: {res, err} = (IV[0] == 1'b1) ? {{W{1'b0}}, A << 1,   1'b0} : 1;
            10: {res, err} = (IV[1] == 1'b1) ? {{W{1'b0}}, B >> 1,   1'b0} : 1;
            11: {res, err} = (IV[1] == 1'b1) ? {{W{1'b0}}, B << 1,   1'b0} : 1;
            12: begin
                if(IV == 2'b11) begin
                    err = ~|B[W-1:RW] ? 0 : 1;
                    res = (A << B[RW-1:0] | A >> (W - B[RW-1:0])) & {W{1'b1}};
                end else begin
                    err = 1;
                end
            end
            13: begin
                if(IV == 2'b11) begin
                    err = ~|B[W-1:RW] ? 0 : 1;
                    res = (A >> B[RW-1:0] | A << (W - B[RW-1:0])) & {W{1'b1}};
                end else begin
                    err = 1;
                end
            end
            default: err = 1;
        endcase
    end
end
endmodule
