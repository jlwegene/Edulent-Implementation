`timescale 1ns / 1ps

module main(sck, seg, an, clk, miso, mosi, cs);
    input sck, mosi, cs, clk;
    output miso;
    output [6:0] seg;
    output [3:0] an;

    reg [7:0] shiftReg, data, command, nb, sendback, curMemOut, makeVerilogHappy;
    reg [7:0] A, B, AR, DR, PC, AP, IR, T, SP, MP, op;
    reg [8:0] bigReg;
    reg [20:0] q;
    reg [7:0] stack [0:255];
    reg [7:0] io [0:255];
    reg [3:0] PSW;
    reg halt, trace, regDump, memDump;
    reg [3:0] curRegOut;
    
    wire [3:0] disp;

    assign miso = shiftReg[7];

    dispMulti dm(disp, io[0], io[1], q, an);
    bin2seg b2s(disp, seg);
    initial begin
//        makeVerilogHappy = 256;
        A = 1;
        B = 2;
        AR = 0;
        DR = 0;
        PC = 0;
        AP = 0;
        IR = 0;
        T = 0;
        SP = 0;
        MP = 0;
        curRegOut = 0;
        regDump = 0;
        PSW = 12;
        //halt = 1;
        //trace = 1;
    end

    always @(posedge sck && ~cs) begin
        shiftReg = {shiftReg[6:0], mosi};
        nb = nb + 1;
        if(memDump) begin
            if(nb == 8) begin
                if(curMemOut == SP)begin
                    memDump = 0;
                end
                else begin
                    shiftReg = stack[curMemOut];
                    curMemOut = curMemOut + 1;
                end
                nb = 0;
            end
        end
        else if(regDump)begin
            if(nb == 8) begin
                case(curRegOut)
                    0 : shiftReg = B;
                    1 : shiftReg = AR;
                    2 : shiftReg = DR;
                    3 : shiftReg = PC;
                    4 : shiftReg = AP;
                    5 : shiftReg = IR;
                    6 : shiftReg = T;
                    7 : shiftReg = PSW;
                    8 : begin shiftReg = 22; regDump = 0;end
                endcase
                curRegOut = curRegOut + 1;
                nb = 0;
            end
        end
        else begin
            if(nb == 8) begin
                command = shiftReg;
                case(command)
                    66 :  begin shiftReg = A; regDump = 1; nb = 0; curRegOut = 0; end
                    67 :  begin curMemOut = 1; shiftReg = stack[0]; memDump = 1; nb = 0; end
                endcase
            end
            if(nb == 16) begin
                data = shiftReg;
                case(command)
                    4 : shiftReg = 1;
                    8 : if(SP == 0) shiftReg = 1; else shiftReg = 2;
                    9 : if(SP == 256) shiftReg = 1; else shiftReg = 2;
                    10 : begin stack[SP] = data; SP = SP + 1; end
                    11 : begin SP = SP - 1; shiftReg = stack[SP]; end
                    12 : shiftReg = stack[SP-1];
                    13 : shiftReg = SP;
                    64 : begin PSW[3] = 0; PSW[2] = 0;end
                    65 : begin PSW[3] = 0; PSW[2] = 1; shiftReg = 99; end
                endcase
                sendback = shiftReg;
            end
        end
        if(nb == 24) nb = 0;
        
        if(~PSW[3]) begin
            op = stack[PC];
            //T = op[7:4];
            case(op[7:4])
                0 : PC = PC + 1;
                1 : begin
                    // MOV
                    case(op[3:0])
                        1 : A = stack[stack[PC+1]];
                        3 : AP = stack[stack[PC+1]];
                        4 : begin A = stack[AP]; PC = PC - 1; end
                        9 : A = stack[PC+1];
                        11: AP = stack[PC+1];
                        12: B = stack[PC+1];
                    endcase
                    PC = PC + 2;
                    end
                3 : begin
                        // ADD
                        case(op[3:0])
                            1 : begin 
                                bigReg = A + stack[stack[PC+1]];
                                A = bigReg[7:0];
                                PSW[0] = bigReg[8];
                                if(A == 0) PSW[1] = 1;
                                else PSW[1] = 0;
                            end
                            4 : begin 
                                bigReg = A + stack[AP];
                                A = bigReg[7:0];
                                PSW[0] = bigReg[8];
                                if(A == 0) PSW[1] = 1;
                                else PSW[1] = 0;
                                PC = PC - 1; 
                            end
                            9 : begin 
                                bigReg = A + stack[PC + 1]; 
                                A = bigReg[7:0];
                                PSW[0] = bigReg[8];
                                if(A == 0) PSW[1] = 1;
                                else PSW[1] = 0;
                            end
                            11: begin 
                                bigReg = AP + stack[PC + 1];
                                AP = bigReg[7:0];
                                PSW[0] = bigReg[8];
                                if(AP == 0) PSW[1] = 1;
                                else PSW[1] = 0;
                            end
                        endcase
                        PC = PC + 2; 
                    end
                4 : begin
                    // SUB
                    case(op[3:0])
                        1 : begin 
                            bigReg = A - stack[stack[PC+1]];
                            A = bigReg[7:0];
                            PSW[0] = bigReg[8];
                            if(A == 0) PSW[1] = 1;
                            else PSW[1] = 0;
                        end
                        4 : begin 
                            bigReg = A - stack[AP];
                            A = bigReg[7:0];
                            PSW[0] = bigReg[8];
                            if(A == 0) PSW[1] = 1;
                            else PSW[1] = 0;
                            PC = PC - 1; 
                        end
                        9 : begin 
                            bigReg = A - stack[PC + 1]; 
                            A = bigReg[7:0];
                            PSW[0] = bigReg[8];
                            if(A == 0) PSW[1] = 1;
                            else PSW[1] = 0;
                        end
                        11: begin 
                            bigReg = AP - stack[PC + 1];
                            AP = bigReg[7:0];
                            PSW[0] = bigReg[8];
                            if(AP == 0) PSW[1] = 1;
                            else PSW[1] = 0;
                        end
                        12 : begin 
                            bigReg = B - stack[PC + 1]; 
                            B = bigReg[7:0];
                            PSW[0] = bigReg[8];
                            if(B == 0) PSW[1] = 1;
                            else PSW[1] = 0;
                        end
                    endcase
                    PC = PC + 2;
                                
                end
                5 : begin
                    // NOT
                    A = ~A;
                    if(A == 0) PSW[1] = 1;
                    else PSW[1] = 0;
                    PC = PC + 1;
                end
                6 : begin
                    // OR
                    case(op[3:0])
                        1 : A = A | stack[stack[PC+1]];
                        9 : A = A | stack[PC+1];
                    endcase
                    PC = PC + 2;
                    if(A == 0) PSW[1] = 1;
                    else PSW[1] = 0;
                end
                7 : begin 
                    // AND
                    case(op[3:0])
                        1 : A = A & stack[stack[PC+1]];
                        9 : A = A & stack[PC+1];
                    endcase
                    PC = PC + 2;
                    if(A == 0) PSW[1] = 1;
                    else PSW[1] = 0;       
                end
                8 : begin
                    // XOR
                    case(op[3:0])
                        1 : A = A ^ stack[stack[PC+1]];
                        9 : A = A ^ stack[PC+1];
                    endcase
                    PC = PC + 2;
                    if(A == 0) PSW[1] = 1;
                    else PSW[1] = 0;       
                end
                9 : begin
                        // SHR
                        PSW[0] = A[0];
                        A = A[7:1];
                        if(A==0) PSW[1] = 1;
                        else PSW[1] = 0;
                        PC = PC + 1;
                end
                10: begin
                    case(op[3:0])
                        1 : PC = stack[PC + 1];
                        5 : begin 
                            if(PSW[1] == 1) PC = stack[PC + 1]; 
                            else PC = PC + 2; 
                        end
                        9 : begin 
                            if(PSW[0] == 1) PC = stack[PC + 1]; 
                            else PC = PC + 2;
                        end
                    endcase
                end
                14 : begin
                    io[stack[PC+1]] = A;
                    PC = PC + 2;
                end
                15 : begin
                    case(op[3:0])
                        0 : PSW[3] = 1;
                        1 : PSW[2] = 1;
                    endcase
                    PC = PC + 1;
                end
                
           endcase
           if(PSW[2] == 1) PSW[3] = 1;       
        end
        
        
    end

    always @(posedge clk) begin
        q <= q + 1;
    end

//    always @(posedge q[16]) begin
//        A = cs;
//        B = halt;
//        AP = AP + 1;
        
//    end

endmodule

module dispMulti(disp, data, command, q, an);
    input [7:0] data, command;
    input [13:0] q;
    output [3:0] disp, an;

    wire a, b, c, d;

    assign a = q[11] & q[12];
    assign b = ~q[11] & q[12];
    assign c = q[11] & ~q[12];
    assign d = ~q[11] & ~q[12];


    assign disp[0] = (data[0]&a) | (data[4]&b) | (command[0]&c) | (command[4]&d);
    assign disp[1] = (data[1]&a) | (data[5]&b) | (command[1]&c) | (command[5]&d);
    assign disp[2] = (data[2]&a) | (data[6]&b) | (command[2]&c) | (command[6]&d);
    assign disp[3] = (data[3]&a) | (data[7]&b) | (command[3]&c) | (command[7]&d);
    assign an[3] = ~d;
    assign an[2] = ~c;
    assign an[1] = ~b;
    assign an[0] = ~a;

endmodule

module bin2seg(B, S);
 input [3:0] B;
 output [6:0] S;
 wire m0, m1, m2, m3, m4, m5, m6, m7, m8, m9, m11, m12, m13, m14, m15;

 assign m0 = ~B[3] & ~B[2] & ~B[1] & ~B[0];
 assign m1 = ~B[3] & ~B[2] & ~B[1] & B[0];
 assign m2 = ~B[3] & ~B[2] & B[1] & ~B[0];
 assign m3 = ~B[3] & ~B[2] & B[1] & B[0];
 assign m4 = ~B[3] & B[2] & ~B[1] & ~B[0];
 assign m5 = ~B[3] & B[2] & ~B[1] & B[0];
 assign m6 = ~B[3] & B[2] & B[1] & ~B[0];
 assign m7 = ~B[3] & B[2] & B[1] & B[0];
 assign m8 = B[3] & ~B[2] & ~B[1] & ~B[0];
 assign m9 = B[3] & ~B[2] & ~B[1] & B[0];
 assign m10 = B[3] & ~B[2] & B[1] & ~B[0];
 assign m11 = B[3] & ~B[2] & B[1] & B[0];
 assign m12 = B[3] & B[2] & ~B[1] & ~B[0];
 assign m13 = B[3] & B[2] & ~B[1] & B[0];
 assign m14 = B[3] & B[2] & B[1] & ~B[0];
 assign m15 = B[3] & B[2] & B[1] & B[0];

 assign S[0] = ~(m0 | m2 | m3 | m5 | m6 | m7 | m8 | m9 | m10 | m12 | m14 | m15);// A
 assign S[1] = ~(m0 | m1 | m2 | m3 | m4 | m7 | m8 | m9 | m10 | m13); // B
 assign S[2] = ~(m0 | m1 | m3 | m4 | m5 | m6 | m7 | m8 | m9 | m10 | m11 | m13);// C
 assign S[3] = ~(m0 | m2 | m3 | m5 | m6 | m8 | m11| m12| m13 | m14); // D
 assign S[4] = ~(m0 | m2 | m6 | m8 | m10 | m11 | m12| m13| m14 | m15); // E
 assign S[5] = ~(m0 | m4 | m5 | m6 | m8 | m9 | m10| m11| m12 | m14 | m15); // F
 assign S[6] = ~(m2 | m3 | m4 | m5 | m6 | m8 | m9 | m10| m11 | m13 | m14 | m15);// G
endmodule
