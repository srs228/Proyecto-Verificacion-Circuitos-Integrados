/*  Fabiola Munoz
    Maria Fernanda Retana
    Sebastian Rojas */

// ============================================================
// Subscriber de cobertura funcional (uvm_subscriber)
//
// Se conecta al MISMO analysis port del monitor que el scoreboard
// (ver diagrama: Monitor -> Analysis port -> {Scoreboard, Subscriber}).
// Mientras el scoreboard VERIFICA los datos, el subscriber MIDE
// que tanto del espacio de instrucciones fue ejercitado.
//
// Requiere que OPC_RTYPE / OPC_ITYPE / OPC_LUI / OPC_AUIPC / OPC_JAL
// esten visibles: subscriber.sv debe compilarse DESPUES de scoreboard.sv
// (donde se definen esos localparam) y la transaccion instr_txn.
// ============================================================
class core_subscriber extends uvm_subscriber #(instr_txn);

    `uvm_component_utils(core_subscriber)

    // Variables intermedias que muestrea el covergroup.
    bit [6:0] cov_opcode;
    bit [2:0] cov_funct3;
    bit [6:0] cov_funct7;
    bit [4:0] cov_rd;
    bit [4:0] cov_rs1;
    bit [4:0] cov_rs2;

    // --------------------------------------------------------
    // Covergroup: 9 coverpoints + 3 crosscoverages
    // Muestreo explicito (sin reloj): se invoca con .sample()
    // --------------------------------------------------------
    covergroup cg_instr;
        option.per_instance = 1;
        option.name         = "cg_instr";

        // (1) Formato/opcode de la instruccion.
        cp_opcode : coverpoint cov_opcode {
            bins RTYPE = {OPC_RTYPE};
            bins ITYPE = {OPC_ITYPE};
            bins LUI   = {OPC_LUI};
            bins AUIPC = {OPC_AUIPC};
            bins JAL   = {OPC_JAL};
            bins otros = default;   // loads/stores/branches: no penaliza cobertura
        }

        // (2) Registro destino rd (RV32E = 16 registros).
        //     x16..x31 no deberian existir -> illegal_bins.
        cp_rd : coverpoint cov_rd {
            bins x[]            = {[0:15]};
            illegal_bins fuera  = {[16:31]};
        }

        // (3) Registro fuente rs1 (solo R e I lo usan).
        cp_rs1 : coverpoint cov_rs1
            iff (cov_opcode == OPC_RTYPE || cov_opcode == OPC_ITYPE) {
            bins x[]            = {[0:15]};
            illegal_bins fuera  = {[16:31]};
        }

        // (4) Registro fuente rs2 (solo R lo usa).
        cp_rs2 : coverpoint cov_rs2 iff (cov_opcode == OPC_RTYPE) {
            bins x[]            = {[0:15]};
            illegal_bins fuera  = {[16:31]};
        }

        // (5) Campo funct3 (definido para R e I).
        cp_funct3 : coverpoint cov_funct3
            iff (cov_opcode == OPC_RTYPE || cov_opcode == OPC_ITYPE) {
            bins f[] = {[0:7]};
        }

        // (6) Campo funct7 (definido para R-type; distingue ADD/SUB, SRL/SRA).
        cp_funct7 : coverpoint cov_funct7 iff (cov_opcode == OPC_RTYPE) {
            bins normal = {7'b0000000};
            bins alt    = {7'b0100000};
            bins otros  = default;
        }

        // (7) Operacion R-type especifica = {funct7, funct3}.
        cp_rtype_op : coverpoint {cov_funct7, cov_funct3}
            iff (cov_opcode == OPC_RTYPE) {
            bins ADD   = {10'b0000000_000};
            bins SUB   = {10'b0100000_000};
            bins SLL   = {10'b0000000_001};
            bins SLT   = {10'b0000000_010};
            bins SLTU  = {10'b0000000_011};
            bins XOR_  = {10'b0000000_100};
            bins SRL   = {10'b0000000_101};
            bins SRA   = {10'b0100000_101};
            bins OR_   = {10'b0000000_110};
            bins AND_  = {10'b0000000_111};
            bins otros = default;
        }

        // (8) Operacion I-type especifica (por funct3).
        //     SRLI y SRAI comparten funct3=101 -> bin SR_I.
        cp_itype_op : coverpoint cov_funct3 iff (cov_opcode == OPC_ITYPE) {
            bins ADDI  = {3'b000};
            bins SLTI  = {3'b010};
            bins SLTIU = {3'b011};
            bins XORI  = {3'b100};
            bins ORI   = {3'b110};
            bins ANDI  = {3'b111};
            bins SLLI  = {3'b001};
            bins SR_I  = {3'b101};
        }

        // (9) Escritura a x0 (caso especial RV32E: debe descartarse).
        cp_rd_zero : coverpoint (cov_rd == 5'd0) {
            bins escribe_x0   = {1};
            bins escribe_otro = {0};
        }

        // --------------------------------------------------------
        // Crosscoverages
        // --------------------------------------------------------
        // (A) Que tipo de instruccion escribio en cada registro destino.
        cross_op_rd    : cross cp_opcode, cp_rd;

        // (B) Cada operacion R-type ejercitada con cada destino.
        cross_rtype_rd : cross cp_rtype_op, cp_rd;

        // (C) Todas las combinaciones de registros fuente (puertos de lectura).
        cross_rs1_rs2  : cross cp_rs1, cp_rs2;

    endgroup

    // --------------------------------------------------------
    // Constructor: el covergroup DEBE construirse aqui.
    // --------------------------------------------------------
    function new(string name, uvm_component parent);
        super.new(name, parent);
        cg_instr = new();
    endfunction

    // --------------------------------------------------------
    // write(): obligatorio en uvm_subscriber.
    // El monitor lo invoca por cada transaccion via analysis_export.
    // --------------------------------------------------------
    function void write(instr_txn t);
        t.decode();

        cov_opcode = t.opcode;
        cov_funct3 = t.funct3;
        cov_funct7 = t.funct7;
        cov_rd     = t.rd;
        cov_rs1    = t.rs1;
        cov_rs2    = t.rs2;

        cg_instr.sample();
    endfunction

    // --------------------------------------------------------
    // Reporte final de cobertura.
    // --------------------------------------------------------
    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("COV",
            $sformatf("Cobertura funcional (cg_instr): %0.2f %%",
                      cg_instr.get_coverage()), UVM_NONE)
    endfunction

endclass