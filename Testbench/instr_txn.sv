// Opcodes RV32 (compartidos con scoreboard.sv y subscriber.sv)
localparam bit [6:0] OPC_RTYPE = 7'b0110011;  // R : ADD, SUB, SLL, ...
localparam bit [6:0] OPC_ITYPE = 7'b0010011;  // I : ADDI, SLTI, SLLI, ...
localparam bit [6:0] OPC_LUI   = 7'b0110111;  // U : LUI
localparam bit [6:0] OPC_AUIPC = 7'b0010111;  // U : AUIPC
localparam bit [6:0] OPC_JAL   = 7'b1101111;  // J : JAL (opcional)
localparam bit [6:0] OPC_LOAD  = 7'b0000011;  // I : LW  (loads)
localparam bit [6:0] OPC_STYPE = 7'b0100011;  // S : SB, SH, SW
localparam bit [6:0] OPC_BTYPE = 7'b1100011;  // B : BEQ, BNE, BLT, BGE, BLTU, BGEU
localparam bit [6:0] OPC_JALR  = 7'b1100111;  // I : JALR

// Tipos de instrucción soportados por la sequence
typedef enum int unsigned {
    INSTR_R = 0,
    INSTR_I = 1,
    INSTR_U = 2,
    INSTR_L = 3,
    INSTR_S = 4,
    INSTR_B = 5,
    INSTR_J = 6
} instr_type_e;

//Paso 1: Crear la clase que extiende de la clase base uvm_sequence_item
class instr_txn extends uvm_sequence_item;

    //Paso 2: Registrarse en la fábrica con macros de campo
    `uvm_object_utils_begin(instr_txn)
        `uvm_field_int(pc,            UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(instr,         UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(rs1_val,       UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(rs2_val,       UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(rd_val_actual, UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(is_last,       UVM_ALL_ON)
    `uvm_object_utils_end

    //Paso 3: Declarar los campos de la transacción

    // Campos capturados por el monitor (observados del DUT)
    bit [31:0] pc;
    bit [31:0] instr;
    bit [31:0] rs1_val;
    bit [31:0] rs2_val;
    bit [31:0] rd_val_actual;
    bit        is_last;

    // Tipo de instrucción (para generación y covergroup)
    rand instr_type_e instr_type;

    // Campos rand — usados para generar y también para decodificar
    rand bit [4:0] rd;
    rand bit [4:0] rs1;
    rand bit [4:0] rs2;
    rand bit [2:0] funct3;
    rand bit [6:0] funct7;
    rand bit [11:0] imm12;
    rand bit [19:0] imm20;

    // Opcode (derivado, no rand)
    bit [6:0] opcode;

    // Inmediatos decodificados
    bit [31:0] imm_i;
    bit [31:0] imm_u;
    bit [31:0] imm_j;
    bit [31:0] imm_b;   // B-type (BRANCH)
    bit [31:0] imm_s;   // S-type (STORE)

    // Capturado por el monitor de fetch (verificacion de ramas, check_btype):
    // next_pc = PC de la siguiente instruccion retirada; valido si next_pc_valid=1.
    bit [31:0] next_pc;
    bit        next_pc_valid;

    // Capturado por el monitor del bus de datos (verificacion de stores, check_stype):
    bit [31:0] mem_addr;    // DADDR  (rs1 + imm_s)
    bit [31:0] mem_wdata;   // DATAO  (dato escrito)
    bit        mem_valid;   // 1 cuando hay una escritura observada

    // Restricciones de aleatoriedad
    constraint c_tipo_dist {
        instr_type dist { INSTR_R := 40, INSTR_I := 40, INSTR_U := 20 };
    }

    constraint c_registros {
        rd  inside {[1:15]};
        rs1 inside {[1:15]};
        rs2 inside {[1:15]};
    }

    constraint c_rtype {
        if (instr_type == INSTR_R) {
            {funct7, funct3} inside {
                10'b0000000_000, 10'b0100000_000, 10'b0000000_001,
                10'b0000000_010, 10'b0000000_011, 10'b0000000_100,
                10'b0000000_101, 10'b0100000_101, 10'b0000000_110,
                10'b0000000_111
            };
        }
    }

    constraint c_itype {
        if (instr_type == INSTR_I) {
            funct3 inside {3'b000, 3'b010, 3'b011, 3'b100, 3'b110, 3'b111};
            funct7 == 7'b0000000;
        }
    }

    constraint c_utype {
        if (instr_type == INSTR_U) {
            funct3 == 3'b000;
            funct7 == 7'b0000000;
        }
    }

    //Paso 4: Crear el constructor
    function new(string name = "instr_txn");
        super.new(name);
    endfunction

    // post_randomize: ensamblar el campo 'instr' a partir de los campos rand
    function void post_randomize();
        bit [6:0] uop;
        case (instr_type)
            INSTR_R: instr = {funct7, rs2, rs1, funct3, rd, 7'b0110011};
            INSTR_I: instr = {imm12,  rs1, funct3, rd,  7'b0010011};
            INSTR_U: begin
                uop   = ($urandom_range(0, 1)) ? 7'b0110111 : 7'b0010111;
                instr = {imm20, rd, uop};
            end
        endcase
        opcode = instr[6:0];
    endfunction

    // decode: poblar todos los campos a partir del campo 'instr'
    // (llamado por el monitor y el scoreboard)
    function void decode();
        opcode = instr[6:0];
        rd     = instr[11:7];
        funct3 = instr[14:12];
        rs1    = instr[19:15];
        rs2    = instr[24:20];
        funct7 = instr[31:25];
        imm_i  = {{20{instr[31]}}, instr[31:20]};
        imm_u  = {instr[31:12], 12'b0};
        imm_j  = {{11{instr[31]}}, instr[31], instr[19:12],
                  instr[20], instr[30:21], 1'b0};
        // B-type: imm = { [12]=i31, [11]=i7, [10:5]=i30:25, [4:1]=i11:8, 0 }
        imm_b  = {{19{instr[31]}}, instr[31], instr[7],
                  instr[30:25], instr[11:8], 1'b0};
        // S-type: imm = { [11:5]=i31:25, [4:0]=i11:7 }
        imm_s  = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    endfunction

    // instr_type_str: nombre legible del tipo de instrucción
    function string instr_type_str();
        case (instr_type)
            INSTR_R: return "R-type";
            INSTR_I: return "I-type";
            INSTR_U: return "U-type";
            INSTR_L: return "L-type";
            INSTR_S: return "S-type";
            INSTR_B: return "B-type";
            INSTR_J: return "J-type";
            default:  return "UNKNOWN";
        endcase
    endfunction

    // convert2string: resumen de una línea para uvm_info
    function string convert2string();
        return $sformatf(
            "instr=0x%08h [%s] op=%07b f3=%03b f7=%07b rd=x%0d rs1=x%0d rs2=x%0d imm12=0x%03h",
            instr, instr_type_str(), opcode, funct3, funct7, rd, rs1, rs2, imm12);
    endfunction

endclass
