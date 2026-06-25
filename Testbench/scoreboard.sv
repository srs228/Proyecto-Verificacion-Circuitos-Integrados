/*  Fabiola Munoz
    Maria Fernanda Retana
    Sebastian Rojas */

// ============================================================
// NOTA: este archivo usa UVM. El top del ambiente debe tener:
//     `include "uvm_macros.svh"
//     import uvm_pkg::*;
// y compilarse con un simulador con soporte UVM (VCS, Questa,
// Xcelium o Riviera-PRO en EDAPlayground).
// ============================================================
// NOTA 2: instr_txn y los localparam OPC_* ESTAN DEFINIDOS
// EN ESTE ARCHIVO. Por lo tanto:
//   - Incluir scoreboard.sv ANTES de cualquier archivo que use
//     instr_txn (subscriber.sv, monitor.sv, driver.sv, checker.sv,
//     env.sv). interface.sv puede ir antes porque no usa instr_txn.
// ============================================================

// ============================================================
// Opcodes RV32
// ============================================================
localparam bit [6:0] OPC_RTYPE = 7'b0110011;  // R : ADD, SUB, SLL, ...
localparam bit [6:0] OPC_ITYPE = 7'b0010011;  // I : ADDI, SLTI, SLLI, ...
localparam bit [6:0] OPC_LUI   = 7'b0110111;  // U : LUI
localparam bit [6:0] OPC_AUIPC = 7'b0010111;  // U : AUIPC
localparam bit [6:0] OPC_BTYPE = 7'b1100011;  // B : BEQ, BNE, BLT, BGE, BLTU, BGEU
localparam bit [6:0] OPC_STYPE = 7'b0100011;  // S : SB, SH, SW
localparam bit [6:0] OPC_JAL   = 7'b1101111;  // J : JAL (opcional)

// ============================================================
// Transaccion (uvm_sequence_item)
// ============================================================
class instr_txn extends uvm_sequence_item;

    // Capturado en el ciclo de retiro:
    bit [31:0] pc;
    bit [31:0] instr;
    bit [31:0] rs1_val;
    bit [31:0] rs2_val;

    // Resultado escrito en rd (R / I / U / JAL).
    bit [31:0] rd_val_actual;

    // Campos decodificados (auxiliares)
    bit [4:0]  rs1, rs2, rd;
    bit [2:0]  funct3;
    bit [6:0]  funct7, opcode;

    // Inmediatos con extension de signo / formato
    bit [31:0] imm_i;
    bit [31:0] imm_u;
    bit [31:0] imm_j;
    bit [31:0] imm_b;   // B-type
    bit [31:0] imm_s;   // S-type

    // Para verificar B-type: PC de la SIGUIENTE instruccion retirada.
    // Lo llena el monitor de fetch con captura diferida:
    //   - al ver una rama, guarda la transaccion
    //   - en el siguiente retiro, copia ese PC a next_pc y next_pc_valid=1
    bit [31:0] next_pc;
    bit        next_pc_valid;

    // Para verificar S-type: observacion del bus de datos del core.
    // Lo llena el monitor del bus al ver un store:
    //   mem_addr  = DADDR  (rs1 + imm_s)
    //   mem_wdata = DATAO  (dato escrito)
    //   mem_valid = 1 cuando hay una escritura observada
    bit [31:0] mem_addr;
    bit [31:0] mem_wdata;
    bit        mem_valid;

    // Registro en la fabrica + macros de campo (copy, compare, print, ...)
    `uvm_object_utils_begin(instr_txn)
        `uvm_field_int(pc,            UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(instr,         UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(rs1_val,       UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(rs2_val,       UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(rd_val_actual, UVM_ALL_ON | UVM_HEX)
    `uvm_object_utils_end

    function new(string name = "instr_txn");
        super.new(name);
    endfunction

    function void decode();
        opcode = instr[6:0];
        rd     = instr[11:7];
        funct3 = instr[14:12];
        rs1    = instr[19:15];
        rs2    = instr[24:20];
        funct7 = instr[31:25];

        // I-type: imm[11:0] = instr[31:20] (con extension de signo)
        imm_i = {{20{instr[31]}}, instr[31:20]};

        // U-type: imm[31:12] = instr[31:12], 12 bits bajos en cero
        imm_u = {instr[31:12], 12'b0};

        // J-type: imm = { [20]=i31, [19:12]=i19:12, [11]=i20, [10:1]=i30:21, 0 }
        imm_j = {{11{instr[31]}}, instr[31], instr[19:12],
                 instr[20], instr[30:21], 1'b0};

        // B-type: imm = { [12]=i31, [11]=i7, [10:5]=i30:25, [4:1]=i11:8, 0 }
        imm_b = {{19{instr[31]}}, instr[31], instr[7],
                 instr[30:25], instr[11:8], 1'b0};

        // S-type: imm = { [11:5]=i31:25, [4:0]=i11:7 }
        imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    endfunction
endclass

// Declarar los dos sufijos de uvm_analysis_imp
// (deben estar antes de la clase que los usa)
`uvm_analysis_imp_decl( _rdifc )
`uvm_analysis_imp_decl( _wrifc )

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
    bit signed [31:0] a_s = $signed(a);
    case ({funct7, funct3})
        10'b0000000_000: predict_rtype = a + b;                             // ADD
        10'b0100000_000: predict_rtype = a - b;                             // SUB
        10'b0000000_001: predict_rtype = a << shamt;                        // SLL
        10'b0000000_010: predict_rtype = ($signed(a) < $signed(b)) ? 1 : 0; // SLT
        10'b0000000_011: predict_rtype = (a < b) ? 1 : 0;                   // SLTU
        10'b0000000_100: predict_rtype = a ^ b;                             // XOR
        10'b0000000_101: predict_rtype = a >> shamt;                        // SRL
        10'b0100000_101: predict_rtype = $unsigned(a_s >>> shamt);          // SRA
        10'b0000000_110: predict_rtype = a | b;                             // OR
        10'b0000000_111: predict_rtype = a & b;                             // AND
        default:         predict_rtype = 32'hDEAD_BEEF;                     // ilegal
    endcase
endfunction

// --- Tipo I (ALU inmediato) ---  imm ya viene extendido a 32 bits
function automatic bit [31:0] predict_itype(
    input bit [31:0] a,
    input bit [31:0] imm,
    input bit [2:0]  funct3,
    input bit [6:0]  funct7   // distingue SRLI (0000000) de SRAI (0100000)
);
    bit [4:0] shamt = imm[4:0];
    bit signed [31:0] a_s = $signed(a);
    case (funct3)
        3'b000: predict_itype = a + imm;                                // ADDI
        3'b010: predict_itype = ($signed(a) < $signed(imm)) ? 1 : 0;    // SLTI
        3'b011: predict_itype = (a < imm) ? 1 : 0;                      // SLTIU
        3'b100: predict_itype = a ^ imm;                                // XORI
        3'b110: predict_itype = a | imm;                                // ORI
        3'b111: predict_itype = a & imm;                                // ANDI
        3'b001: predict_itype = a << shamt;                             // SLLI
        3'b101: begin
            if (funct7 == 7'b0100000)
                predict_itype = $unsigned(a_s >>> shamt);              // SRAI
            else
                predict_itype = a >> shamt;                            // SRLI
        end
        default: predict_itype = 32'hDEAD_BEEF;                         // ilegal
    endcase
endfunction

// --- Tipo U (LUI / AUIPC) ---
function automatic bit [31:0] predict_utype(
    input bit [6:0]  opcode,
    input bit [31:0] pc,
    input bit [31:0] imm_u
);
    case (opcode)
        OPC_LUI:   predict_utype = imm_u;          // LUI   : rd = imm[31:12] << 12
        OPC_AUIPC: predict_utype = pc + imm_u;     // AUIPC : rd = pc + (imm[31:12] << 12)
        default:   predict_utype = 32'hDEAD_BEEF;  // ilegal
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
        default: predict_branch_taken = 1'b0;                        // ilegal
    endcase
endfunction

// --- Tipo S (dato efectivamente almacenado, enmascarado por tamaño) ---
function automatic bit [31:0] predict_store_data(
    input bit [31:0] rs2_val,
    input bit [2:0]  funct3
);
    case (funct3)
        3'b000: predict_store_data = {24'b0, rs2_val[7:0]};    // SB
        3'b001: predict_store_data = {16'b0, rs2_val[15:0]};   // SH
        3'b010: predict_store_data = rs2_val;                  // SW
        default: predict_store_data = 32'hDEAD_BEEF;           // ilegal
    endcase
endfunction

// ============================================================
// Scoreboard (uvm_scoreboard)
// ============================================================
class core_scoreboard extends uvm_scoreboard;

    // Registro en la fabrica
    `uvm_component_utils(core_scoreboard)

    // Puertos de analisis duales:
    //   _rdifc  ← agent_read.monitor_obj   (lado fetch/predict)
    //   _wrifc  ← agent.monitor_write_obj  (lado write-back/observe)
    uvm_analysis_imp_rdifc #(instr_txn, core_scoreboard) uvm_analysis_imp_rdifc_obj;
    uvm_analysis_imp_wrifc #(instr_txn, core_scoreboard) uvm_analysis_imp_wrifc_obj;

    // Estadisticas
    int unsigned num_checked;
    int unsigned num_passed;
    int unsigned num_failed;
    int unsigned num_skipped;      // opcode no modelado
    int unsigned num_unverified;   // B/S sin observacion (next_pc / bus)

    // Contadores por instruccion (cobertura informal)
    int unsigned op_count [string];

    // ------------------------------------------------------------
    // Constructor UVM
    // ------------------------------------------------------------
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    // ------------------------------------------------------------
    // build_phase: crear los dos analysis imp
    // ------------------------------------------------------------
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        uvm_analysis_imp_rdifc_obj =
            new("uvm_analysis_imp_rdifc_obj", this);
        uvm_analysis_imp_wrifc_obj =
            new("uvm_analysis_imp_wrifc_obj", this);
    endfunction

    // ------------------------------------------------------------
    // write_rdifc(): recibe transacción del monitor de fetch.
    // En esta arquitectura el fetch-monitor captura la instrucción
    // antes del write-back; se puede usar para almacenar el lado
    // 'expected' si se quiere implementar match-por-PC.
    // ------------------------------------------------------------
    virtual function void write_rdifc(instr_txn t);
        verificar(t);
    endfunction

    // write_wrifc: recibe transacción del Monitor W (estimulo, rd_val_actual=0).
    // Sólo se registra como informativo — la verificación ocurre en write_rdifc.
    virtual function void write_wrifc(instr_txn t);
        t.decode();
        `uvm_info("SB",
            $sformatf("[SB] Estimulo observado: pc=0x%08h instr=0x%08h op=%07b rs1=x%0d(0x%08h) rs2=x%0d(0x%08h)",
                      t.pc, t.instr, t.opcode, t.rs1, t.rs1_val, t.rs2, t.rs2_val),
            UVM_HIGH)
    endfunction

    // ------------------------------------------------------------
    // verificar(): despachador por opcode
    // ------------------------------------------------------------
    function void verificar(instr_txn t);
        t.decode();
        case (t.opcode)
            OPC_RTYPE          : check_rtype(t);
            OPC_ITYPE          : check_itype(t);
            OPC_LUI, OPC_AUIPC : check_utype(t);
            OPC_BTYPE          : check_btype(t);   // ramas
            OPC_STYPE          : check_stype(t);   // stores
            OPC_JAL            : check_jal(t);     // opcional
            default            : num_skipped++;    // loads, system, ...
        endcase
    endfunction

    // ------------------------------------------------------------
    // Verificacion compartida de escritura a rd (R / I / U / JAL)
    // ------------------------------------------------------------
    function void check_rd_write(instr_txn t, bit [31:0] expected,
                                 string mnemonic, string operandos);
        op_count[mnemonic]++;

        // RV32E: x0 fijo en cero. Las escrituras a x0 se descartan.
        if (t.rd == 5'd0) begin
            num_checked++;
            if (t.rd_val_actual !== 32'h0) begin
                num_failed++;
                `uvm_error("SB", $sformatf(
                    "x0 no permanece en cero! pc=%08h instr=%08h x0=%08h",
                    t.pc, t.instr, t.rd_val_actual))
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
            `uvm_info("SB", $sformatf(
                "PASS pc=%08h %-5s x%0d <- %08h | %s",
                t.pc, mnemonic, t.rd, t.rd_val_actual, operandos), UVM_MEDIUM)
        end
        else begin
            num_failed++;
            `uvm_error("SB", $sformatf(
                "FAIL pc=%08h %-5s x%0d: esperado=%08h obtenido=%08h | %s",
                t.pc, mnemonic, t.rd, expected, t.rd_val_actual, operandos))
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
    // U-type (LUI / AUIPC)
    // ------------------------------------------------------------
    function void check_utype(instr_txn t);
        bit [31:0] expected;
        string     m;
        string     ops;
        expected = predict_utype(t.opcode, t.pc, t.imm_u);
        m   = (t.opcode == OPC_LUI) ? "LUI" : "AUIPC";
        ops = $sformatf("imm_u=%08h, pc=%08h", t.imm_u, t.pc);
        check_rd_write(t, expected, m, ops);
    endfunction

    // ------------------------------------------------------------
    // B-type: NO escribe registro. Se verifica el flujo de control.
    // destino_esperado = tomada ? (pc + imm_b) : (pc + 4)
    // Se compara contra next_pc (PC de la siguiente instruccion).
    // Requiere t.next_pc_valid (lo llena el monitor de fetch con
    // captura diferida: guarda la rama y completa next_pc en el
    // siguiente retiro).
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
            num_unverified++;
            `uvm_info("SB", $sformatf(
                "INFO pc=%08h %-4s tomada_esp=%0b destino_esp=%08h (sin next_pc: no verificado)",
                t.pc, m, taken_esp, target_esp), UVM_LOW)
            return;
        end

        num_checked++;
        if (t.next_pc === target_esp) begin
            num_passed++;
            `uvm_info("SB", $sformatf(
                "PASS pc=%08h %-4s tomada=%0b destino=%08h | rs1=x%0d=%08h, rs2=x%0d=%08h",
                t.pc, m, taken_esp, t.next_pc,
                t.rs1, t.rs1_val, t.rs2, t.rs2_val), UVM_MEDIUM)
        end
        else begin
            num_failed++;
            `uvm_error("SB", $sformatf(
                "FAIL pc=%08h %-4s destino_esp=%08h destino_obt=%08h (tomada_esp=%0b) | rs1=x%0d=%08h, rs2=x%0d=%08h",
                t.pc, m, target_esp, t.next_pc, taken_esp,
                t.rs1, t.rs1_val, t.rs2, t.rs2_val))
        end
    endfunction

    // ------------------------------------------------------------
    // S-type: NO escribe registro. Escribe en MEMORIA.
    // direccion_esperada = rs1 + imm_s
    // dato_esperado      = rs2 enmascarado segun tamaño (SB/SH/SW)
    // Se compara contra la observacion del bus de datos del core
    // (mem_addr / mem_wdata), que debe llenar el monitor del bus.
    //
    // NOTA byte-lane: este check asume que el bus presenta el dato
    // alineado a la derecha (bytes bajos). Si DarkRISCV coloca el
    // byte en la pista segun addr[1:0], ajustar el enmascarado de
    // mem_wdata usando t.mem_addr[1:0].
    // ------------------------------------------------------------
    function void check_stype(instr_txn t);
        bit [31:0] addr_esp;
        bit [31:0] data_esp;
        bit        addr_ok;
        bit        data_ok;
        string     m;

        m = stype_name(t.funct3);
        op_count[m]++;

        addr_esp = t.rs1_val + t.imm_s;
        data_esp = predict_store_data(t.rs2_val, t.funct3);

        // Sin observacion del bus no se puede verificar.
        if (!t.mem_valid) begin
            num_unverified++;
            `uvm_info("SB", $sformatf(
                "INFO pc=%08h %-4s addr_esp=%08h data_esp=%08h (sin observacion de bus: no verificado)",
                t.pc, m, addr_esp, data_esp), UVM_LOW)
            return;
        end

        num_checked++;
        addr_ok = (t.mem_addr === addr_esp);
        case (t.funct3)
            3'b000: data_ok = (t.mem_wdata[7:0]  === data_esp[7:0]);   // SB
            3'b001: data_ok = (t.mem_wdata[15:0] === data_esp[15:0]);  // SH
            3'b010: data_ok = (t.mem_wdata       === data_esp);        // SW
            default: data_ok = 1'b0;
        endcase

        if (addr_ok && data_ok) begin
            num_passed++;
            `uvm_info("SB", $sformatf(
                "PASS pc=%08h %-4s [%08h] <- %08h | rs1=x%0d=%08h, imm=%08h, rs2=x%0d=%08h",
                t.pc, m, t.mem_addr, t.mem_wdata,
                t.rs1, t.rs1_val, t.imm_s, t.rs2, t.rs2_val), UVM_MEDIUM)
        end
        else begin
            num_failed++;
            `uvm_error("SB", $sformatf(
                "FAIL pc=%08h %-4s addr_esp=%08h addr_obt=%08h | data_esp=%08h data_obt=%08h (addr_ok=%0b data_ok=%0b)",
                t.pc, m, addr_esp, t.mem_addr, data_esp, t.mem_wdata, addr_ok, data_ok))
        end
    endfunction

    // ------------------------------------------------------------
    // JAL : verifica el enlace rd = pc + 4.
    // El destino del salto requeriria next_pc (no implementado aqui).
    // ------------------------------------------------------------
    function void check_jal(instr_txn t);
        bit [31:0] expected_link;
        string     ops;
        expected_link = t.pc + 32'd4;
        ops = $sformatf("destino=%08h", t.pc + t.imm_j);
        check_rd_write(t, expected_link, "JAL", ops);
    endfunction

    // ------------------------------------------------------------
    // report_phase: resumen final (UVM_NONE -> siempre se imprime)
    // ------------------------------------------------------------
    function void report_phase(uvm_phase phase);
        string linea;
        super.report_phase(phase);

        `uvm_info("SB", "==================== Resumen del Scoreboard ====================", UVM_NONE)
        `uvm_info("SB", $sformatf("Verificadas  : %0d", num_checked), UVM_NONE)
        `uvm_info("SB", $sformatf("Exitosas     : %0d", num_passed),  UVM_NONE)
        `uvm_info("SB", $sformatf("Fallidas     : %0d", num_failed),  UVM_NONE)
        `uvm_info("SB", $sformatf("Sin verificar: %0d (falta next_pc / observacion de bus)", num_unverified), UVM_NONE)
        `uvm_info("SB", $sformatf("Omitidas     : %0d (opcode no modelado)", num_skipped), UVM_NONE)
        `uvm_info("SB", "Conteo por instruccion:", UVM_NONE)
        foreach (op_count[op]) begin
            linea = $sformatf("  %-6s : %0d", op, op_count[op]);
            `uvm_info("SB", linea, UVM_NONE)
        end
        `uvm_info("SB", "===============================================================", UVM_NONE)
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

    function string stype_name(bit [2:0] f3);
        case (f3)
            3'b000: return "SB";
            3'b001: return "SH";
            3'b010: return "SW";
            default: return "S-ILLEGAL";
        endcase
    endfunction

    // ============================================================
    // Funciones publicas para el checker (si se conserva)
    // ============================================================
    function bit [31:0] get_expected_utype(
        input bit [6:0] opcode, input bit [31:0] pc, input bit [31:0] imm_u);
        return predict_utype(opcode, pc, imm_u);
    endfunction

    function bit get_branch_taken(
        input bit [31:0] rs1_val, input bit [31:0] rs2_val, input bit [2:0] funct3);
        return predict_branch_taken(rs1_val, rs2_val, funct3);
    endfunction

    function bit [31:0] get_store_data(
        input bit [31:0] rs2_val, input bit [2:0] funct3);
        return predict_store_data(rs2_val, funct3);
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

    function string get_stype_name(input bit [2:0] funct3);
        return stype_name(funct3);
    endfunction

endclass