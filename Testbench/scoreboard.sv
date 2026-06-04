/*  Fabiola Munoz
    Maria Fernanda Retana
    Sebastian Rojas */


// ============================================================
// Opcodes RV32 (a nivel de unidad de compilacion)
// ============================================================
localparam bit [6:0] OPC_RTYPE = 7'b0110011;  // R  : ADD, SUB, SLL, ...
localparam bit [6:0] OPC_ITYPE = 7'b0010011;  // I  : ADDI, SLTI, SLLI, ...
localparam bit [6:0] OPC_BTYPE = 7'b1100011;  // B  : BEQ, BNE, BLT, ...
localparam bit [6:0] OPC_JAL   = 7'b1101111;  // J  : JAL

// ============================================================
// Transaccion: una instruccion retirada
// ============================================================
class instr_txn; // taxonomia de instruccion, como estan divididos los bits
    // Capturado en el ciclo de retiro:
    bit [31:0] pc;
    bit [31:0] instr;
    bit [31:0] rs1_val;
    bit [31:0] rs2_val;

    // Resultado escrito en rd (para R / I / JAL).
    bit [31:0] rd_val_actual;

    // PC de la SIGUIENTE instruccion retirada.
    // Necesario para verificar ramas (B) y el destino de JAL.
    // El monitor debe llenarlo un retiro despues (patron diferido).
    bit [31:0] next_pc;
    bit        next_pc_valid;

    // Campos decodificados (auxiliares)
    bit [4:0]  rs1, rs2, rd;
    bit [2:0]  funct3;
    bit [6:0]  funct7, opcode;

    // Inmediatos con extension de signo
    bit [31:0] imm_i;
    bit [31:0] imm_b;
    bit [31:0] imm_j;

    function void decode();
        opcode = instr[6:0];
        rd     = instr[11:7];
        funct3 = instr[14:12];
        rs1    = instr[19:15];
        rs2    = instr[24:20];
        funct7 = instr[31:25];

        // I-type: imm[11:0] = instr[31:20]
        imm_i = {{20{instr[31]}}, instr[31:20]};

        // B-type: imm = { [12]=i31, [11]=i7, [10:5]=i30:25, [4:1]=i11:8, 0 }
        imm_b = {{19{instr[31]}}, instr[31], instr[7],
                 instr[30:25], instr[11:8], 1'b0};

        // J-type: imm = { [20]=i31, [19:12]=i19:12, [11]=i20, [10:1]=i30:21, 0 }
        imm_j = {{11{instr[31]}}, instr[31], instr[19:12],
                 instr[20], instr[30:21], 1'b0};
    endfunction
endclass

// ============================================================
// Modelos de referencia
// ============================================================

// --- Tipo R ---
function automatic bit [31:0] predict_rtype(
    input bit [31:0] a,
    input bit [31:0] b,
    input bit [2:0]  funct3,
    input bit [6:0]  funct7
);
    bit [4:0] shamt = b[4:0];
    case ({funct7, funct3})
        10'b0000000_000: predict_rtype = a + b;                             // ADD
        10'b0100000_000: predict_rtype = a - b;                             // SUB
        10'b0000000_001: predict_rtype = a << shamt;                        // SLL
        10'b0000000_010: predict_rtype = ($signed(a) < $signed(b)) ? 1 : 0; // SLT
        10'b0000000_011: predict_rtype = (a < b) ? 1 : 0;                   // SLTU
        10'b0000000_100: predict_rtype = a ^ b;                             // XOR
        10'b0000000_101: predict_rtype = a >> shamt;                        // SRL
        10'b0100000_101: predict_rtype = $signed(a) >>> shamt;              // SRA
        10'b0000000_110: predict_rtype = a | b;                             // OR
        10'b0000000_111: predict_rtype = a & b;                             // AND
        default:         predict_rtype = 32'hDEAD_BEEF;                     // Tipo R ilegal
    endcase
endfunction

// --- Tipo I (ALU inmediato) ---
// El inmediato 'imm' ya viene con extension de signo a 32 bits.
function automatic bit [31:0] predict_itype(
    input bit [31:0] a,
    input bit [31:0] imm,
    input bit [2:0]  funct3,
    input bit [6:0]  funct7   // distingue SRLI (0000000) de SRAI (0100000)
);
    bit [4:0] shamt = imm[4:0];   // para shifts, shamt = imm[4:0] = instr[24:20]
    case (funct3)
        3'b000: predict_itype = a + imm;                                // ADDI
        3'b010: predict_itype = ($signed(a) < $signed(imm)) ? 1 : 0;    // SLTI
        3'b011: predict_itype = (a < imm) ? 1 : 0;                      // SLTIU (compara sin signo)
        3'b100: predict_itype = a ^ imm;                                // XORI
        3'b110: predict_itype = a | imm;                                // ORI
        3'b111: predict_itype = a & imm;                                // ANDI
        3'b001: predict_itype = a << shamt;                             // SLLI
        3'b101: predict_itype = (funct7 == 7'b0100000)
                                  ? ($signed(a) >>> shamt)              // SRAI
                                  : (a >> shamt);                       // SRLI
        default: predict_itype = 32'hDEAD_BEEF;                         // Tipo I ilegal
    endcase
endfunction

// --- Tipo B (decide si la rama se toma) ---
function automatic bit predict_branch_taken(
    input bit [31:0] a,
    input bit [31:0] b,
    input bit [2:0]  funct3
);
    case (funct3)
        3'b000: predict_branch_taken = (a == b);                     // BEQ
        3'b001: predict_branch_taken = (a != b);                     // BNE
        3'b100: predict_branch_taken = ($signed(a) <  $signed(b));   // BLT
        3'b101: predict_branch_taken = ($signed(a) >= $signed(b));   // BGE
        3'b110: predict_branch_taken = (a <  b);                     // BLTU
        3'b111: predict_branch_taken = (a >= b);                     // BGEU
        default: predict_branch_taken = 1'b0;                        // Tipo B ilegal
    endcase
endfunction

// ============================================================
// Scoreboard
// ============================================================
class core_scoreboard;

    // Canal de entrada: el monitor envia las transacciones por aqui
    mailbox #(instr_txn) mbx;

    // Estadisticas
    int unsigned num_checked;
    int unsigned num_passed;
    int unsigned num_failed;
    int unsigned num_skipped;          // opcode no modelado (loads, stores, LUI, ...)
    int unsigned num_branch_pending;   // ramas sin next_pc -> no se pudo verificar destino

    // Contadores por instruccion (utiles para reportes de cobertura)
    int unsigned op_count [string];

    function new(mailbox #(instr_txn) mbx);
        this.mbx                = mbx;
        this.num_checked        = 0;
        this.num_passed         = 0;
        this.num_failed         = 0;
        this.num_skipped        = 0;
        this.num_branch_pending = 0;
    endfunction

    // Lazo principal: se ejecuta como un proceso desde el env
    task run();
        instr_txn t;
        forever begin
            mbx.get(t);     // Espera la siguiente transaccion del monitor
            check(t);
        end
    endtask

    // ------------------------------------------------------------
    // Despachador: decide el tipo de instruccion segun el opcode
    // ------------------------------------------------------------
    function void check(instr_txn t);
        t.decode();
        case (t.opcode)
            OPC_RTYPE: check_rtype(t);
            OPC_ITYPE: check_itype(t);
            OPC_JAL  : check_jal(t);
            OPC_BTYPE: check_btype(t);
            default  : num_skipped++;   // no modelado en este avance
        endcase
    endfunction

    // ------------------------------------------------------------
    // Verificacion compartida de escritura a rd (R / I / JAL)
    // ------------------------------------------------------------
    function void check_rd_write(instr_txn t, bit [31:0] expected,
                                 string mnemonic, string operandos);
        op_count[mnemonic]++;

        // RV32E: x0 fijo en cero. Las escrituras a x0 se descartan.
        if (t.rd == 5'd0) begin
            num_checked++;
            if (t.rd_val_actual !== 32'h0) begin
                num_failed++;
                $display("[SB][ERROR] x0 no permanece en cero! pc=%08h instr=%08h x0=%08h",
                         t.pc, t.instr, t.rd_val_actual);
            end
            else begin
                num_passed++;
            end
            return;
        end

        // Comparacion normal
        num_checked++;
        if (t.rd_val_actual === expected) begin
            num_passed++;
            $display("[SB][PASS] pc=%08h %-5s x%0d <- %08h | %s",
                     t.pc, mnemonic, t.rd, t.rd_val_actual, operandos);
        end
        else begin
            num_failed++;
            $display("[SB][FAIL] pc=%08h %-5s x%0d: esperado=%08h obtenido=%08h | %s",
                     t.pc, mnemonic, t.rd, expected, t.rd_val_actual, operandos);
        end
    endfunction

    // ------------------------------------------------------------
    // R-type
    // ------------------------------------------------------------
    function void check_rtype(instr_txn t);
        bit [31:0] expected;
        string     ops;
        expected = predict_rtype(t.rs1_val, t.rs2_val, t.funct3, t.funct7);
        ops = $sformatf("rs1=x%0d=%08h, rs2=x%0d=%08h",
                        t.rs1, t.rs1_val, t.rs2, t.rs2_val);
        check_rd_write(t, expected, rtype_name(t.funct3, t.funct7), ops);
    endfunction

    // ------------------------------------------------------------
    // I-type (ALU inmediato)
    // ------------------------------------------------------------
    function void check_itype(instr_txn t);
        bit [31:0] expected;
        string     ops;
        expected = predict_itype(t.rs1_val, t.imm_i, t.funct3, t.funct7);
        ops = $sformatf("rs1=x%0d=%08h, imm=%08h",
                        t.rs1, t.rs1_val, t.imm_i);
        check_rd_write(t, expected, itype_name(t.funct3, t.funct7), ops);
    endfunction

    // ------------------------------------------------------------
    // JAL: escribe el enlace (rd = pc+4) y salta a (pc + imm_j).
    // El enlace se verifica como cualquier escritura a rd.
    // El destino del salto se verifica si el monitor capturo next_pc.
    // ------------------------------------------------------------
    function void check_jal(instr_txn t);
        bit [31:0] expected_link;
        bit [31:0] target;
        string     ops;

        expected_link = t.pc + 32'd4;       // direccion de retorno
        target        = t.pc + t.imm_j;     // destino del salto
        ops = $sformatf("destino=%08h", target);

        // 1) Verifica el enlace (rd = pc+4)
        check_rd_write(t, expected_link, "JAL", ops);

        // 2) Verifica el salto en si (opcional, requiere next_pc)
        if (t.next_pc_valid) begin
            if (t.next_pc !== target) begin
                num_failed++;
                $display("[SB][FAIL] pc=%08h JAL  destino esperado=%08h obtenido=%08h",
                         t.pc, target, t.next_pc);
            end
        end
    endfunction

    // ------------------------------------------------------------
    // B-type: no escribe registro. Se verifica el flujo de control.
    // expected_target = tomada ? (pc + imm_b) : (pc + 4)
    // Se compara contra el PC de la siguiente instruccion (next_pc).
    // ------------------------------------------------------------
    function void check_btype(instr_txn t);
        bit        taken_esp;
        bit [31:0] target_esp;
        string     m;

        m = btype_name(t.funct3);
        op_count[m]++;

        taken_esp  = predict_branch_taken(t.rs1_val, t.rs2_val, t.funct3);
        target_esp = taken_esp ? (t.pc + t.imm_b) : (t.pc + 32'd4);

        // Sin next_pc no se puede confirmar la direccion tomada.
        if (!t.next_pc_valid) begin
            num_branch_pending++;
            $display("[SB][INFO] pc=%08h %-5s tomada_esp=%0b destino_esp=%08h (sin next_pc: no verificado)",
                     t.pc, m, taken_esp, target_esp);
            return;
        end

        num_checked++;
        if (t.next_pc === target_esp) begin
            num_passed++;
            $display("[SB][PASS] pc=%08h %-5s tomada=%0b destino=%08h | rs1=x%0d=%08h, rs2=x%0d=%08h",
                     t.pc, m, taken_esp, t.next_pc,
                     t.rs1, t.rs1_val, t.rs2, t.rs2_val);
        end
        else begin
            num_failed++;
            $display("[SB][FAIL] pc=%08h %-5s destino esperado=%08h obtenido=%08h (tomada_esp=%0b) | rs1=x%0d=%08h, rs2=x%0d=%08h",
                     t.pc, m, target_esp, t.next_pc, taken_esp,
                     t.rs1, t.rs1_val, t.rs2, t.rs2_val);
        end
    endfunction

    // ------------------------------------------------------------
    // Reporte final
    // ------------------------------------------------------------
    function void report();
        $display("==================== Resumen del Scoreboard ====================");
        $display("Verificadas         : %0d", num_checked);
        $display("Exitosas            : %0d", num_passed);
        $display("Fallidas            : %0d", num_failed);
        $display("Ramas sin verificar : %0d (falta next_pc)", num_branch_pending);
        $display("Omitidas            : %0d (opcode no modelado)", num_skipped);
        $display("----------------------------------------------------------------");
        $display("Conteo por instruccion:");
        foreach (op_count[op])
            $display("  %-6s : %0d", op, op_count[op]);
        $display("=================================================================");
    endfunction

    // ============================================================
    // Funciones auxiliares de nombres
    // ============================================================
    function string rtype_name(bit [2:0] f3, bit [6:0] f7);
        case ({f7, f3})
            10'b0000000_000: return "ADD";
            10'b0100000_000: return "SUB";
            10'b0000000_001: return "SLL";
            10'b0000000_010: return "SLT";
            10'b0000000_011: return "SLTU";
            10'b0000000_100: return "XOR";
            10'b0000000_101: return "SRL";
            10'b0100000_101: return "SRA";
            10'b0000000_110: return "OR";
            10'b0000000_111: return "AND";
            default:         return "ILLEGAL";
        endcase
    endfunction

    function string itype_name(bit [2:0] f3, bit [6:0] f7);
        case (f3)
            3'b000: return "ADDI";
            3'b010: return "SLTI";
            3'b011: return "SLTIU";
            3'b100: return "XORI";
            3'b110: return "ORI";
            3'b111: return "ANDI";
            3'b001: return "SLLI";
            3'b101: return (f7 == 7'b0100000) ? "SRAI" : "SRLI";
            default: return "I-ILLEGAL";
        endcase
    endfunction

    function string btype_name(bit [2:0] f3);
        case (f3)
            3'b000: return "BEQ";
            3'b001: return "BNE";
            3'b100: return "BLT";
            3'b101: return "BGE";
            3'b110: return "BLTU";
            3'b111: return "BGEU";
            default: return "B-ILLEGAL";
        endcase
    endfunction

    // ============================================================
    // Funciones publicas para el checker
    // ============================================================
    function bit [31:0] get_expected_rtype(
        input bit [31:0] rs1_val, input bit [31:0] rs2_val,
        input bit [2:0]  funct3,  input bit [6:0]  funct7);
        return predict_rtype(rs1_val, rs2_val, funct3, funct7);
    endfunction

    function bit [31:0] get_expected_itype(
        input bit [31:0] rs1_val, input bit [31:0] imm,
        input bit [2:0]  funct3,  input bit [6:0]  funct7);
        return predict_itype(rs1_val, imm, funct3, funct7);
    endfunction

    function bit get_branch_taken(
        input bit [31:0] rs1_val, input bit [31:0] rs2_val,
        input bit [2:0]  funct3);
        return predict_branch_taken(rs1_val, rs2_val, funct3);
    endfunction

    function string get_rtype_name(input bit [2:0] funct3, input bit [6:0] funct7);
        return rtype_name(funct3, funct7);
    endfunction

    function string get_itype_name(input bit [2:0] funct3, input bit [6:0] funct7);
        return itype_name(funct3, funct7);
    endfunction

    function string get_btype_name(input bit [2:0] funct3);
        return btype_name(funct3);
    endfunction

    //-----------------------------------------------------------

endclass