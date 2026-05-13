/*  Fabiola Munoz
    Maria Fernanda Retana
    Sebastian Rojas */

// Transacción: una instrucción tipo R retirada
// ============================================================
class instr_txn; // taxonomia de instruccion, como estan dividos los bits
    // Capturado en el ciclo de retiro (antes del writeback):
    bit [31:0] pc;
    bit [31:0] instr;
    bit [31:0] rs1_val;
    bit [31:0] rs2_val;

    // Capturado un ciclo después del retiro (writeback visible):
    bit [31:0] rd_val_actual;

    // Campos decodificados (auxiliares)
    bit [4:0]  rs1, rs2, rd;
    bit [2:0]  funct3;
    bit [6:0]  funct7, opcode;

    function void decode();
        opcode = instr[6:0];
        rd     = instr[11:7];
        funct3 = instr[14:12];
        rs1    = instr[19:15];
        rs2    = instr[24:20];
        funct7 = instr[31:25];
    endfunction
endclass

// Modelo de referencia para instrucciones tipo R
// ============================================================
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

// ============================================================
// Scoreboard
// ============================================================
class core_scoreboard;

    // Canal de entrada: el monitor envía las transacciones por aquí
    mailbox #(instr_txn) mbx;

    // Estadísticas
    int unsigned num_checked;
    int unsigned num_passed;
    int unsigned num_failed;
    int unsigned num_skipped;     // No es tipo R

    // Contadores por instrucción (útiles para reportes de cobertura)
    int unsigned op_count [string];

    function new(mailbox #(instr_txn) mbx);
        this.mbx         = mbx;
        this.num_checked = 0;
        this.num_passed  = 0;
        this.num_failed  = 0;
        this.num_skipped = 0;
    endfunction

    // Lazo principal: se ejecuta como un proceso desde el top
    task run();
        instr_txn t;
        forever begin
            mbx.get(t);     // Espera la siguiente transacción del monitor
            check(t);
        end
    endtask

    // Verifica una transacción contra el modelo de referencia
    function void check(instr_txn t);
        bit [31:0] expected;
        string     mnemonic;

        t.decode();

    // Filtro: el primer avance solo cubre instrucciones tipo R
        if (t.opcode !== 7'b0110011) begin
            num_skipped++;
            return;
        end

        // Calcula el resultado esperado usando el modelo de referencia
        expected = predict_rtype(t.rs1_val, t.rs2_val, t.funct3, t.funct7);
        mnemonic = rtype_name(t.funct3, t.funct7);
        op_count[mnemonic]++;

        // Verificación de RV32E: x0 debe estar fijo en cero.
        // Regla arquitectónica: las escrituras a x0 deben descartarse.
        if (t.rd == 5'd0) begin
            if (t.rd_val_actual !== 32'h0) begin
                num_failed++;
                $display("[SB][ERROR] ¡x0 no está fijo en cero! pc=%08h instr=%08h x0=%08h",
                         t.pc, t.instr, t.rd_val_actual);
            end
            else begin
                num_passed++;
            end
                num_checked++;
            return;
        end

        // Comparación normal para instrucciones tipo R
        num_checked++;
        if (t.rd_val_actual === expected) begin
            num_passed++;
            $display("[SB][PASS] pc=%08h %s x%0d=x%0d(%08h),x%0d(%08h) -> %08h",
                     t.pc, mnemonic, t.rd, t.rs1, t.rs1_val,
                     t.rs2, t.rs2_val, t.rd_val_actual);
        end
        else begin
            num_failed++;
            $display("[SB][FAIL] pc=%08h %s x%0d: esperado=%08h obtenido=%08h (rs1=x%0d=%08h, rs2=x%0d=%08h)",
                     t.pc, mnemonic, t.rd, expected, t.rd_val_actual,
                     t.rs1, t.rs1_val, t.rs2, t.rs2_val);
        end
    endfunction

     // Reporte final: llamar desde el top al terminar la simulación
    function void report();
        $display("==================== Resumen del Scoreboard ====================");
        $display("Verificadas : %0d", num_checked);
        $display("Exitosas    : %0d", num_passed);
        $display("Fallidas    : %0d", num_failed);
        $display("Omitidas    : %0d (no son tipo R)", num_skipped);
        foreach (op_count[op])
            $display("  %-5s : %0d", op, op_count[op]);
        $display("=================================================================");
    endfunction

    // Función auxiliar: devuelve el nombre del tipo R para mejorar los logs
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
  
  
      // Función pública para que el checker pida el resultado esperado
    function bit [31:0] get_expected_rtype(
        input bit [31:0] rs1_val,
        input bit [31:0] rs2_val,
        input bit [2:0]  funct3,
        input bit [6:0]  funct7
    );
        return predict_rtype(rs1_val, rs2_val, funct3, funct7);
    endfunction


    // Función pública para que el checker imprima el nombre de la instrucción
    function string get_rtype_name(
        input bit [2:0] funct3,
        input bit [6:0] funct7
    );
        return rtype_name(funct3, funct7);
    endfunction
  
  //-----------------------------------------------------------
  
endclass
