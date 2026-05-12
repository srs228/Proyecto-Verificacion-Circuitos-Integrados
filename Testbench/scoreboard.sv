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
