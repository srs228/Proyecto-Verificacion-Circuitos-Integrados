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

    // Aserción 1: Registro x0
    // En palabras: Si el procesador está funcionando (fuera de reset), 
    // el valor del registro x0 siempre debe ser exactamente 0.
    property p_x0_siempre_cero;
        @(posedge clk) (!reset_core) |-> (x0 == 32'b0);
    endproperty

    asercion_x0: assert property (p_x0_siempre_cero)
        else $error("Fallo de Aserción 1: El registro x0 cambió su valor %0t", $time);


    // Aserción 2: Comportamiento seguro del Reset
    // En palabras: Si la señal de reset_core está en alto (activa),
    // la dirección de instrucción (iaddr) debe mantenerse en 0.
    property p_reset_limpia_pc;
        @(posedge clk) (reset_core) |-> (iaddr == 32'b0);
    endproperty

    asercion_reset: assert property (p_reset_limpia_pc)
        else $error("Fallo de Aserción 2: El iaddr no es 0 durante el reset en el tiempo %0t", $time);


    // Aserción 3: Prevención de estados desconocidos en el bus de instrucciones
    // En palabras: Si el procesador está funcionando (fuera de reset),
    // la dirección de instrucción (iaddr) nunca debe ser un valor desconocido (X o Z).
    property p_iaddr_valido;
        @(posedge clk) disable iff (reset_core) !$isunknown(iaddr);
    endproperty

    asercion_iaddr_valido: assert property (p_iaddr_valido)
        else $error("Fallo de Aserción 3: El bus de direcciones iaddr tiene un valor desconocido en el tiempo %0t", $time);

endinterface

