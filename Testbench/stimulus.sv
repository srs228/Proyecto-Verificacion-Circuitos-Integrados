class core_stimulus;

    rand int unsigned kind;
    rand logic [4:0] rd;
    rand logic [4:0] rs1;
    rand logic [4:0] rs2;
    rand logic [2:0] f3;
    rand logic [6:0] f7;
    rand logic [11:0] imm12;
    rand logic [19:0] imm20;

    constraint c_kind { kind inside {[0:2]}; }
    constraint c_regs {
        rd  inside {[1:15]};
        rs1 inside {[1:15]};
        rs2 inside {[1:15]};
    }

    function automatic logic [31:0] enc_r(
        input logic [6:0] funct7,
        input logic [4:0] rs2_i,
        input logic [4:0] rs1_i,
        input logic [2:0] funct3,
        input logic [4:0] rd_i,
        input logic [6:0] opcode
    );
        return {funct7, rs2_i, rs1_i, funct3, rd_i, opcode};
    endfunction

    function automatic logic [31:0] enc_i(
        input logic [11:0] imm_i,
        input logic [4:0] rs1_i,
        input logic [2:0] funct3,
        input logic [4:0] rd_i,
        input logic [6:0] opcode
    );
        return {imm_i, rs1_i, funct3, rd_i, opcode};
    endfunction

    function automatic logic [31:0] enc_u(
        input logic [19:0] imm_i,
        input logic [4:0] rd_i,
        input logic [6:0] opcode
    );
        return {imm_i, rd_i, opcode};
    endfunction

    function void add_bootstrap(ref logic [31:0] prog[$]);
        int unsigned r;
        logic [11:0] seed_imm;
        logic [4:0]  rd_reg;

        for (r = 1; r <= 15; r++) begin
            seed_imm = (12'((r * 17) + 3)) & 12'h7ff;
            rd_reg   = r[4:0];
            prog.push_back(enc_i(seed_imm, 5'd0, 3'b000, rd_reg, 7'b0010011));
        end
    endfunction

    function logic [31:0] build_random_word();
        logic [31:0] w;
        logic [4:0] shamt;

        void'(this.randomize());
        shamt = rs2[4:0];

        case (kind)
            0: begin
                void'(this.randomize(f3, f7) with {
                    ({f7, f3} inside {
                        10'b0000000_000,
                        10'b0100000_000,
                        10'b0000000_001,
                        10'b0000000_010,
                        10'b0000000_011,
                        10'b0000000_100,
                        10'b0000000_101,
                        10'b0100000_101,
                        10'b0000000_110,
                        10'b0000000_111
                    });
                });
                w = enc_r(f7, rs2, rs1, f3, rd, 7'b0110011);
            end

            1: begin
                void'(this.randomize(f3, imm12) with {
                    f3 inside {3'b000, 3'b010, 3'b011, 3'b100, 3'b110, 3'b111};
                });
                w = enc_i(imm12, rs1, f3, rd, 7'b0010011);
            end

            default: begin
                void'(this.randomize(f3, imm12) with {
                    f3 inside {3'b001, 3'b101};
                });
                if (f3 == 3'b001) begin
                    w = enc_i({7'b0000000, shamt}, rs1, f3, rd, 7'b0010011);
                end
                else begin
                    w = enc_i({($urandom_range(0,1) ? 7'b0100000 : 7'b0000000), shamt}, rs1, f3, rd, 7'b0010011);
                end
            end
        endcase

        return w;
    endfunction

    function void build_program(
        output logic [31:0] prog[$],
        input int unsigned random_count
    );
        int unsigned i;

        prog.delete();

        add_bootstrap(prog);

        for (i = 0; i < random_count; i++) begin
            prog.push_back(build_random_word());
        end

        prog.push_back(enc_u(20'h00000, 5'd0, 7'b1101111));
    endfunction

endclass
