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