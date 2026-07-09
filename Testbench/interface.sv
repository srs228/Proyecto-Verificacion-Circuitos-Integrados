interface core_if(input logic clk);

    logic reset_core;
    logic mem_gen_done;
    int unsigned program_words;

    // Registro x0.
    logic [31:0] x0;

    // Señales de control / estado.
    logic r_type;
    logic hlt;
    logic flush;

    // Dirección e instrucción observada.
    logic [31:0] iaddr;
    logic [31:0] xidata;

    // Campos decodificados.
    logic [3:0] rd;
    logic [3:0] rs1;
    logic [3:0] rs2;

    logic [2:0] fct3;
    logic [6:0] fct7;

    // Operandos y resultado observado.
    logic [31:0] u1reg;
    logic [31:0] u2reg;
    logic [31:0] rmdata;

endinterface

