//Paso 1: Crear la clase que extiende de la clase base uvm_sequence
class base_sequence extends uvm_sequence #(instr_txn);

    //Paso 2: Registrarse en la fabrica
    `uvm_object_utils(base_sequence)

    //Paso 3: Declarar variables de configuracion
    int unsigned NUM_INSTR = 220;

    //Paso 4: Constructor
    function new(string name = "base_sequence");
        super.new(name);
    endfunction

    function automatic bit [31:0] mk_r(
        input bit [6:0] f7,
        input bit [4:0] rs2_i,
        input bit [4:0] rs1_i,
        input bit [2:0] f3,
        input bit [4:0] rd_i
    );
        return {f7, rs2_i, rs1_i, f3, rd_i, 7'b0110011};
    endfunction

    function automatic bit [31:0] mk_i(
        input bit [11:0] imm12_i,
        input bit [4:0]  rs1_i,
        input bit [2:0]  f3,
        input bit [4:0]  rd_i
    );
        return {imm12_i, rs1_i, f3, rd_i, 7'b0010011};
    endfunction

    function automatic bit [31:0] mk_u(
        input bit [19:0] imm20_i,
        input bit [4:0]  rd_i,
        input bit [6:0]  opc
    );
        return {imm20_i, rd_i, opc};
    endfunction

    task automatic send_directed(
        input bit [31:0] raw_instr,
        input string tag,
        input instr_type_e t
    );
        instr_txn req;
        req = instr_txn::type_id::create("instr_dirigida");
        start_item(req);
        req.instr = raw_instr;
        req.instr_type = t;
        req.decode();
        finish_item(req);
        `uvm_info("SEQ", $sformatf("[Dirigida] %s instr=0x%08h", tag, req.instr), UVM_MEDIUM)
    endtask

    //Paso 5: En body() generamos y enviamos las transacciones al driver
    task body();
        instr_txn req;
        int unsigned r;
        logic [11:0] seed_imm;
        int unsigned i;

        `uvm_info("SEQ", "=== Iniciando base_sequence ===", UVM_NONE)

        // Bootstrap para inicializar x1..x15 con valores conocidos.
        for (r = 1; r <= 15; r++) begin
            seed_imm = (r * 17 + 3) & 12'h7FF;
            req = instr_txn::type_id::create("bootstrap");
            start_item(req);
            req.instr      = {seed_imm, 5'd0, 3'b000, r[4:0], 7'b0010011};
            req.instr_type = INSTR_I;
            req.rd         = r[4:0];
            req.rs1        = 5'd0;
            req.imm12      = seed_imm;
            req.decode();
            finish_item(req);
            `uvm_info("SEQ",
                $sformatf("[Bootstrap] ADDI x%0d, x0, 0x%03h  instr=0x%08h",
                          r, seed_imm, req.instr),
                UVM_MEDIUM)
        end

        // Barrido dirigido para cubrir operaciones y registros destino.
        for (i = 1; i <= 15; i++) begin
            send_directed(mk_r(7'b0000000, (i % 15) + 1, i[4:0], 3'b000, i[4:0]), "ADD", INSTR_R);
            send_directed(mk_r(7'b0100000, (i % 15) + 1, i[4:0], 3'b000, i[4:0]), "SUB", INSTR_R);
            send_directed(mk_r(7'b0000000, (i % 15) + 1, i[4:0], 3'b001, i[4:0]), "SLL", INSTR_R);
            send_directed(mk_r(7'b0000000, (i % 15) + 1, i[4:0], 3'b010, i[4:0]), "SLT", INSTR_R);
            send_directed(mk_r(7'b0000000, (i % 15) + 1, i[4:0], 3'b011, i[4:0]), "SLTU", INSTR_R);
            send_directed(mk_r(7'b0000000, (i % 15) + 1, i[4:0], 3'b100, i[4:0]), "XOR", INSTR_R);
            send_directed(mk_r(7'b0000000, (i % 15) + 1, i[4:0], 3'b101, i[4:0]), "SRL", INSTR_R);
            send_directed(mk_r(7'b0100000, (i % 15) + 1, i[4:0], 3'b101, i[4:0]), "SRA", INSTR_R);
            send_directed(mk_r(7'b0000000, (i % 15) + 1, i[4:0], 3'b110, i[4:0]), "OR", INSTR_R);
            send_directed(mk_r(7'b0000000, (i % 15) + 1, i[4:0], 3'b111, i[4:0]), "AND", INSTR_R);

            send_directed(mk_i({1'b0, i[4:0], 6'h03}, i[4:0], 3'b000, i[4:0]), "ADDI", INSTR_I);
            send_directed(mk_i({1'b1, i[4:0], 6'h04}, i[4:0], 3'b010, i[4:0]), "SLTI", INSTR_I);
            send_directed(mk_i({1'b1, i[4:0], 6'h05}, i[4:0], 3'b011, i[4:0]), "SLTIU", INSTR_I);
            send_directed(mk_i({1'b1, i[4:0], 6'h06}, i[4:0], 3'b100, i[4:0]), "XORI", INSTR_I);
            send_directed(mk_i({1'b1, i[4:0], 6'h07}, i[4:0], 3'b110, i[4:0]), "ORI", INSTR_I);
            send_directed(mk_i({1'b1, i[4:0], 6'h08}, i[4:0], 3'b111, i[4:0]), "ANDI", INSTR_I);
            send_directed(mk_i({7'b0000000, i[4:0]}, i[4:0], 3'b001, i[4:0]), "SLLI", INSTR_I);
            send_directed(mk_i({7'b0000000, i[4:0]}, i[4:0], 3'b101, i[4:0]), "SRLI", INSTR_I);
            send_directed(mk_i({7'b0100000, i[4:0]}, i[4:0], 3'b101, i[4:0]), "SRAI", INSTR_I);

            send_directed(mk_u({8'h0, i[11:0]}, i[4:0], 7'b0110111), "LUI", INSTR_U);
            send_directed(mk_u({8'h1, i[11:0]}, i[4:0], 7'b0010111), "AUIPC", INSTR_U);
        end

        // Caso dirigido de escritura a x0 (debe descartarse en scoreboard).
        send_directed(mk_i(12'h000, 5'd0, 3'b000, 5'd0), "ADDI x0,x0,0", INSTR_I);

        // Cola aleatoria para completar combinaciones de cobertura.
        repeat (NUM_INSTR) begin
            req = instr_txn::type_id::create("instr_aleatoria");
            start_item(req);
            if (!req.randomize())
                `uvm_error("SEQ", "Fallo en randomize() de instr_txn")
            req.decode();
            finish_item(req);
            `uvm_info("SEQ",
                $sformatf(
                    "------------------------------------------------------------\n[SEQ] Instruccion generada (TEORIA / ESTIMULO)\n  Tipo    : %s\n  instr   : 0x%08h\n  opcode  : %07b\n  rd      : x%0d\n  rs1     : x%0d\n  rs2     : x%0d\n  funct3  : %03b\n  funct7  : %07b\n  imm12   : 0x%03h (signed=%0d)\n------------------------------------------------------------",
                    req.instr_type_str(), req.instr, req.opcode,
                    req.rd, req.rs1, req.rs2,
                    req.funct3, req.funct7,
                    req.imm12, $signed(req.imm12)
                ),
                UVM_NONE)
        end

        `uvm_info("SEQ", "=== base_sequence completada ===", UVM_NONE)
    endtask

endclass

