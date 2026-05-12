/*  Fabiola Munoz
    Maria Fernanda Retana
    Sebastian Rojas */

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
endclass