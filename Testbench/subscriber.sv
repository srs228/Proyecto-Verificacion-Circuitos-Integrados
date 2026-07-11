/*  Fabiola Munoz
    Maria Fernanda Retana
    Sebastian Rojas */

// ============================================================
// Subscriber de cobertura funcional (uvm_subscriber)
//
// Monitor -> analysis port -> { scoreboard (verifica), subscriber (mide) }.
//
// El documento exige, por CADA tipo de instruccion, 6 puntos de
// cobertura y 3 cruces. Para lograrlo se define UN covergroup por
// tipo y se muestrea solo el que corresponde al opcode observado:
//
//   cg_rtype  : R      (ADD,SUB,SLL,SLT,SLTU,XOR,SRL,SRA,OR,AND)
//   cg_itype  : I      (ADDI,SLTI,SLTIU,XORI,ORI,ANDI,SLLI,SRLI,SRAI)
//   cg_utype  : U      (LUI, AUIPC)
//   cg_load   : LOAD   (LW; se reconocen tambien LB/LH/LBU/LHU)
//   cg_store  : STORE  (SW; se reconocen tambien SB/SH)
//   cg_branch : BRANCH (BEQ,BNE,BLT,BGE,BLTU,BGEU)
//   cg_jump   : JUMP   (JAL, JALR)
//
// Cada covergroup tiene 6 coverpoints + 3 cross. Las instrucciones
// "mixtas" reutilizan todos estos puntos (no requieren covergroup
// aparte).
//
// Requiere que los localparam OPC_* y la funcion predict_branch_taken
// (definidos en scoreboard.sv) esten visibles: subscriber.sv debe
// compilarse DESPUES de scoreboard.sv, y despues de instr_txn.
// ============================================================
class core_subscriber extends uvm_subscriber #(instr_txn);

    `uvm_component_utils(core_subscriber)

    // --------------------------------------------------------
    // Variables intermedias que muestrean los covergroups.
    // Se cargan en write() antes de invocar el .sample() correcto.
    // --------------------------------------------------------
    bit [6:0]  s_op;      // opcode
    bit [2:0]  s_f3;      // funct3
    bit [6:0]  s_f7;      // funct7
    bit [4:0]  s_rd;      // registro destino
    bit [4:0]  s_rs1;     // registro fuente 1
    bit [4:0]  s_rs2;     // registro fuente 2
    bit [31:0] s_rs1v;    // valor de rs1
    bit [31:0] s_rs2v;    // valor de rs2 (dato en stores)
    bit [31:0] s_res;     // rd_val_actual (resultado / enlace)
    bit [31:0] s_imm;     // inmediato del formato correspondiente
    bit [31:0] s_addr;    // direccion efectiva (load/store)
    bit [31:0] s_pc;      // PC de la instruccion
    bit        s_taken;   // rama tomada (segun modelo de referencia)

    // ========================================================
    // (1) R-type : 6 coverpoints + 3 cross
    // ========================================================
    covergroup cg_rtype;
        option.per_instance = 1;
        option.name = "cg_rtype";

        cp_op : coverpoint {s_f7, s_f3} {           // operacion R
            bins ADD  = {10'b0000000_000};
            bins SUB  = {10'b0100000_000};
            bins SLL  = {10'b0000000_001};
            bins SLT  = {10'b0000000_010};
            bins SLTU = {10'b0000000_011};
            bins XOR_ = {10'b0000000_100};
            bins SRL  = {10'b0000000_101};
            bins SRA  = {10'b0100000_101};
            bins OR_  = {10'b0000000_110};
            bins AND_ = {10'b0000000_111};
        }
        cp_rd  : coverpoint s_rd  { bins x[] = {[0:15]}; }
        cp_rs1 : coverpoint s_rs1 { bins x[] = {[0:15]}; }
        cp_rs2 : coverpoint s_rs2 { bins x[] = {[0:15]}; }
        cp_rs1v : coverpoint s_rs1v {
            bins cero = {0};
            bins neg  = {[32'h8000_0000:32'hFFFF_FFFF]};
            bins pos  = {[1:32'h7FFF_FFFF]};
        }
        cp_rs2v : coverpoint s_rs2v {
            bins cero = {0};
            bins neg  = {[32'h8000_0000:32'hFFFF_FFFF]};
            bins pos  = {[1:32'h7FFF_FFFF]};
        }

        cross_op_rd   : cross cp_op,  cp_rd;
        cross_op_rs1  : cross cp_op,  cp_rs1;
        cross_rs1_rs2 : cross cp_rs1, cp_rs2;
    endgroup

    // ========================================================
    // (2) I-type : 6 coverpoints + 3 cross
    // ========================================================
    covergroup cg_itype;
        option.per_instance = 1;
        option.name = "cg_itype";

        cp_op : coverpoint s_f3 {                   // operacion I (por funct3)
            bins ADDI  = {3'b000};
            bins SLTI  = {3'b010};
            bins SLTIU = {3'b011};
            bins XORI  = {3'b100};
            bins ORI   = {3'b110};
            bins ANDI  = {3'b111};
            bins SLLI  = {3'b001};
            bins SR_I  = {3'b101};                  // SRLI / SRAI
        }
        cp_sra : coverpoint s_f7[5] iff (s_f3 == 3'b101) {  // distingue SRLI/SRAI
            bins SRLI = {1'b0};
            bins SRAI = {1'b1};
        }
        cp_rd  : coverpoint s_rd  { bins x[] = {[0:15]}; }
        cp_rs1 : coverpoint s_rs1 { bins x[] = {[0:15]}; }
        cp_imm : coverpoint s_imm {
            bins cero = {0};
            bins neg  = {[32'h8000_0000:32'hFFFF_FFFF]};
            bins pos  = {[1:32'h7FFF_FFFF]};
        }
        cp_rs1v : coverpoint s_rs1v {
            bins cero = {0};
            bins neg  = {[32'h8000_0000:32'hFFFF_FFFF]};
            bins pos  = {[1:32'h7FFF_FFFF]};
        }

        cross_op_rd  : cross cp_op, cp_rd;
        cross_op_rs1 : cross cp_op, cp_rs1;
        cross_op_imm : cross cp_op, cp_imm;
    endgroup

    // ========================================================
    // (3) U-type : 6 coverpoints + 3 cross
    // ========================================================
    covergroup cg_utype;
        option.per_instance = 1;
        option.name = "cg_utype";

        cp_op : coverpoint s_op {
            bins LUI   = {OPC_LUI};
            bins AUIPC = {OPC_AUIPC};
        }
        cp_rd : coverpoint s_rd { bins x[] = {[0:15]}; }
        cp_rd_zero : coverpoint (s_rd == 5'd0) {
            bins escribe_x0   = {1};
            bins escribe_otro = {0};
        }
        cp_imm : coverpoint s_imm {
            bins cero = {0};
            bins neg  = {[32'h8000_0000:32'hFFFF_FFFF]};
            bins pos  = {[1:32'h7FFF_FFFF]};
        }
        cp_res : coverpoint s_res {
            bins cero = {0};
            bins neg  = {[32'h8000_0000:32'hFFFF_FFFF]};
            bins pos  = {[1:32'h7FFF_FFFF]};
        }
        cp_pc : coverpoint s_pc {                   // region de PC (relevante para AUIPC)
            bins bajo  = {[32'h0000_0000:32'h0000_00FF]};
            bins medio = {[32'h0000_0100:32'h0000_0FFF]};
            bins alto  = {[32'h0000_1000:32'hFFFF_FFFF]};
        }

        cross_op_rd  : cross cp_op, cp_rd;
        cross_op_imm : cross cp_op, cp_imm;
        cross_op_pc  : cross cp_op, cp_pc;
    endgroup

    // ========================================================
    // (4) LOAD : 6 coverpoints + 3 cross
    // ========================================================
    covergroup cg_load;
        option.per_instance = 1;
        option.name = "cg_load";

        cp_op : coverpoint s_f3 {
            bins LW  = {3'b010};
            // Alcance de rubrica: solo LW. Los demas loads se ignoran.
            ignore_bins LB  = {3'b000};
            ignore_bins LH  = {3'b001};
            ignore_bins LBU = {3'b100};
            ignore_bins LHU = {3'b101};
        }
        cp_rd  : coverpoint s_rd  { bins x[] = {[0:15]}; }
        cp_rs1 : coverpoint s_rs1 { bins x[] = {[0:15]}; }   // registro base
        cp_imm : coverpoint s_imm {                          // desplazamiento
            bins cero = {0};
            bins neg  = {[32'h8000_0000:32'hFFFF_FFFF]};
            bins pos  = {[1:32'h7FFF_FFFF]};
        }
        cp_rd_zero : coverpoint (s_rd == 5'd0) {
            bins carga_x0  = {1};
            bins carga_reg = {0};
        }
        cp_align : coverpoint s_addr[1:0] {                  // alineamiento de la direccion
            bins alineado    = {2'b00};
            bins desalineado = {[2'b01:2'b11]};
        }

        cross_op_rd  : cross cp_op,  cp_rd;
        cross_rs1_rd : cross cp_rs1, cp_rd;
        cross_op_imm : cross cp_op,  cp_imm;
    endgroup

    // ========================================================
    // (5) STORE : 6 coverpoints + 3 cross
    // ========================================================
    covergroup cg_store;
        option.per_instance = 1;
        option.name = "cg_store";

        cp_op : coverpoint s_f3 {
            bins SW = {3'b010};
            // Alcance de rubrica: solo SW. Los demas stores se ignoran.
            ignore_bins SB = {3'b000};
            ignore_bins SH = {3'b001};
        }
        cp_rs1 : coverpoint s_rs1 { bins x[] = {[0:15]}; }   // registro base
        cp_rs2 : coverpoint s_rs2 { bins x[] = {[0:15]}; }   // registro dato
        cp_imm : coverpoint s_imm {                          // desplazamiento
            bins cero = {0};
            bins neg  = {[32'h8000_0000:32'hFFFF_FFFF]};
            bins pos  = {[1:32'h7FFF_FFFF]};
        }
        cp_data : coverpoint s_rs2v {                        // valor almacenado
            bins cero = {0};
            bins neg  = {[32'h8000_0000:32'hFFFF_FFFF]};
            bins pos  = {[1:32'h7FFF_FFFF]};
        }
        cp_align : coverpoint s_addr[1:0] {
            bins alineado    = {2'b00};
            bins desalineado = {[2'b01:2'b11]};
        }

        cross_op_rs2  : cross cp_op,  cp_rs2;
        cross_rs1_rs2 : cross cp_rs1, cp_rs2;
        cross_op_imm  : cross cp_op,  cp_imm;
    endgroup

    // ========================================================
    // (6) BRANCH : 6 coverpoints + 3 cross
    // ========================================================
    covergroup cg_branch;
        option.per_instance = 1;
        option.name = "cg_branch";

        cp_op : coverpoint s_f3 {
            bins BEQ  = {3'b000};
            bins BNE  = {3'b001};
            bins BLT  = {3'b100};
            bins BGE  = {3'b101};
            bins BLTU = {3'b110};
            bins BGEU = {3'b111};
        }
        cp_rs1 : coverpoint s_rs1 { bins x[] = {[0:15]}; }
        cp_rs2 : coverpoint s_rs2 { bins x[] = {[0:15]}; }
        cp_taken : coverpoint s_taken {                      // salto tomado / no tomado
            bins tomada    = {1'b1};
            bins no_tomada = {1'b0};
        }
        cp_dir : coverpoint s_imm[31] {                      // direccion del salto
            bins adelante = {1'b0};
            bins atras    = {1'b1};
        }
        cp_imm : coverpoint s_imm {
            bins cero = {0};
            bins neg  = {[32'h8000_0000:32'hFFFF_FFFF]};
            bins pos  = {[1:32'h7FFF_FFFF]};
        }

        cross_op_taken : cross cp_op,  cp_taken;
        cross_rs1_rs2  : cross cp_rs1, cp_rs2;
        cross_op_dir   : cross cp_op,  cp_dir;
    endgroup

    // ========================================================
    // (7) JUMP : 6 coverpoints + 3 cross
    // ========================================================
    covergroup cg_jump;
        option.per_instance = 1;
        option.name = "cg_jump";

        cp_op : coverpoint s_op {
            bins JAL  = {OPC_JAL};
            bins JALR = {OPC_JALR};
        }
        cp_rd : coverpoint s_rd { bins x[] = {[0:15]}; }     // registro de enlace
        cp_rd_zero : coverpoint (s_rd == 5'd0) {             // salto sin enlace vs con enlace
            bins sin_enlace = {1};
            bins con_enlace = {0};
        }
        cp_rs1 : coverpoint s_rs1 iff (s_op == OPC_JALR) {   // base (solo JALR)
            bins x[] = {[0:15]};
        }
        cp_dir : coverpoint s_imm[31] {                      // direccion del salto
            bins adelante = {1'b0};
            bins atras    = {1'b1};
        }
        cp_link : coverpoint s_res {                         // valor de enlace (pc+4)
            bins cero = {0};
            bins neg  = {[32'h8000_0000:32'hFFFF_FFFF]};
            bins pos  = {[1:32'h7FFF_FFFF]};
        }

        cross_op_rd     : cross cp_op, cp_rd;
        cross_op_rdzero : cross cp_op, cp_rd_zero;
        cross_op_dir    : cross cp_op, cp_dir;
    endgroup

    // --------------------------------------------------------
    // Constructor: TODOS los covergroups deben construirse aqui.
    // --------------------------------------------------------
    function new(string name, uvm_component parent);
        super.new(name, parent);
        cg_rtype  = new();
        cg_itype  = new();
        cg_utype  = new();
        cg_load   = new();
        cg_store  = new();
        cg_branch = new();
        cg_jump   = new();
    endfunction

    // --------------------------------------------------------
    // write(): lo invoca el monitor por cada transaccion.
    // Se cargan las variables y se muestrea SOLO el covergroup
    // que corresponde al opcode observado.
    // --------------------------------------------------------
    function void write(instr_txn t);
        t.decode();

        // Campos comunes.
        s_op   = t.opcode;
        s_f3   = t.funct3;
        s_f7   = t.funct7;
        s_rd   = t.rd;
        s_rs1  = t.rs1;
        s_rs2  = t.rs2;
        s_rs1v = t.rs1_val;
        s_rs2v = t.rs2_val;
        s_res  = t.rd_val_actual;
        s_pc   = t.pc;
        s_imm  = 32'b0;
        s_addr = 32'b0;
        s_taken = 1'b0;

        case (t.opcode)
            OPC_RTYPE : begin
                cg_rtype.sample();
            end
            OPC_ITYPE : begin
                s_imm = t.imm_i;
                cg_itype.sample();
            end
            OPC_LUI, OPC_AUIPC : begin
                s_imm = t.imm_u;
                cg_utype.sample();
            end
            OPC_LOAD : begin
                s_imm  = t.imm_i;
                s_addr = t.rs1_val + t.imm_i;
                cg_load.sample();
            end
            OPC_STYPE : begin
                s_imm  = t.imm_s;
                s_addr = t.rs1_val + t.imm_s;
                cg_store.sample();
            end
            OPC_BTYPE : begin
                s_imm   = t.imm_b;
                s_taken = predict_branch_taken(t.rs1_val, t.rs2_val, t.funct3);
                cg_branch.sample();
            end
            OPC_JAL : begin
                s_imm = t.imm_j;
                cg_jump.sample();
            end
            OPC_JALR : begin
                s_imm = t.imm_i;
                cg_jump.sample();
            end
            default : ; // otros opcodes (FENCE, SYSTEM, ...): sin cobertura
        endcase
    endfunction

    // --------------------------------------------------------
    // Reporte final de cobertura, por tipo y promedio.
    // --------------------------------------------------------
    function void report_phase(uvm_phase phase);
        real cov_prom;
        super.report_phase(phase);

        cov_prom = (cg_rtype.get_coverage()  + cg_itype.get_coverage()  +
                    cg_utype.get_coverage()  + cg_load.get_coverage()   +
                    cg_store.get_coverage()  + cg_branch.get_coverage() +
                    cg_jump.get_coverage()) / 7.0;

        `uvm_info("COV", "============= Cobertura funcional por tipo =============", UVM_NONE)
        `uvm_info("COV", $sformatf("R      : %6.2f %%", cg_rtype.get_coverage()),  UVM_NONE)
        `uvm_info("COV", $sformatf("I      : %6.2f %%", cg_itype.get_coverage()),  UVM_NONE)
        `uvm_info("COV", $sformatf("U      : %6.2f %%", cg_utype.get_coverage()),  UVM_NONE)
        `uvm_info("COV", $sformatf("LOAD   : %6.2f %%", cg_load.get_coverage()),   UVM_NONE)
        `uvm_info("COV", $sformatf("STORE  : %6.2f %%", cg_store.get_coverage()),  UVM_NONE)
        `uvm_info("COV", $sformatf("BRANCH : %6.2f %%", cg_branch.get_coverage()), UVM_NONE)
        `uvm_info("COV", $sformatf("JUMP   : %6.2f %%", cg_jump.get_coverage()),   UVM_NONE)
        `uvm_info("COV", "--------------------------------------------------------", UVM_NONE)
        `uvm_info("COV", $sformatf("Promedio: %6.2f %%", cov_prom), UVM_NONE)
        `uvm_info("COV", "========================================================", UVM_NONE)
    endfunction

endclass
