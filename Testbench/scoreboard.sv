/*  Fabiola Munoz
    Maria Fernanda Retana
    Sebastian Rojas */

`uvm_analysis_imp_decl(_instr)

class core_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(core_scoreboard)

    uvm_analysis_imp_instr #(instr_txn, core_scoreboard) imp;

    // Estadísticas
    int unsigned num_checked;
    int unsigned num_passed;
    int unsigned num_failed;
    int unsigned num_skipped;     // No es tipo R, o caso especial de rd==0

// Contadores por instrucción (útiles para reportes de cobertura)
    int unsigned op_count [string];

    function new(string name, uvm_component parent);
        super.new(name, parent);
        imp = new("imp", this);
    endfunction

    // Llamado por el monitor por cada retiro completado
    function void write_instr(instr_txn t);
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
                `uvm_error("SB",
                    $sformatf("¡x0 no está fijo en cero! pc=%08h instr=%08h x0=%08h",
                              t.pc, t.instr, t.rd_val_actual))
            end
            else num_passed++;
            num_checked++;
            return;
        end

    // Comparación normal para instrucciones tipo R
        num_checked++;
        if (t.rd_val_actual === expected) begin
            num_passed++;
            `uvm_info("SB",
                $sformatf("PASS pc=%08h %s x%0d=x%0d(%08h),x%0d(%08h) -> %08h",
                          t.pc, mnemonic, t.rd, t.rs1, t.rs1_val,
                          t.rs2, t.rs2_val, t.rd_val_actual), UVM_HIGH)
        end
        else begin
            num_failed++;
            `uvm_error("SB",
                $sformatf("FAIL pc=%08h %s x%0d: esperado=%08h obtenido=%08h (rs1=x%0d=%08h, rs2=x%0d=%08h)",
                          t.pc, mnemonic, t.rd, expected, t.rd_val_actual,
                          t.rs1, t.rs1_val, t.rs2, t.rs2_val))
        end
    endfunction