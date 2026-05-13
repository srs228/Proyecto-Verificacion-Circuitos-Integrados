/*  Fabiola Munoz
    Maria Fernanda Retana
    Sebastian Rojas */
// Este componente observa señales internas del DUT mediante core_if.
// Luego le pide al scoreboard el resultado esperado y compara.

class core_checker;

    virtual core_if core_vif;
    core_scoreboard scoreboard;

    int pruebas_correctas;
    int errores;
    int instrucciones_r;
    int errores_x0;
    int numero_prueba;

    function new(virtual core_if core_vif, core_scoreboard scoreboard);

        this.core_vif   = core_vif;
        this.scoreboard = scoreboard;

        pruebas_correctas = 0;
        errores           = 0;
        instrucciones_r   = 0;
        errores_x0        = 0;
      	numero_prueba     = 0;

    endfunction


    // Tarea principal del checker.
    task run();

        forever begin

            @(posedge core_vif.clk);
            #2;

            if (!core_vif.reset_core) begin
                revisar_x0();
                revisar_instruccion_r();
            end

        end

    endtask


    // Verificación de x0.
    function void revisar_x0();

        if (core_vif.x0 !== 32'h0000_0000) begin

            errores++;
            errores_x0++;

            $display("");
            $display("El registro x0 cambio de valor.");
            $display("");
            $display("Valor esperado : 0x00000000");
            $display("Valor observado: 0x%08h", core_vif.x0);
            $display("Tiempo         : %0t ns", $time);
            $display("");

        end

    endfunction


    // Verificación de instrucciones tipo R.
    function void revisar_instruccion_r();

        bit [6:0] opcode;
        bit [2:0] funct3;
        bit [6:0] funct7;

        bit [31:0] esperado;
        bit [31:0] observado;

        string nombre_instr;

        opcode = core_vif.xidata[6:0];
        funct3 = core_vif.xidata[14:12];
        funct7 = core_vif.xidata[31:25];

        // Solo revisar instrucciones tipo R válidas.
        if ((opcode == 7'b0110011) &&
            !core_vif.hlt &&
            !core_vif.flush) begin

            instrucciones_r++;
            numero_prueba++;

            // El scoreboard calcula el resultado esperado.
            esperado = scoreboard.get_expected_rtype(
                core_vif.u1reg,
                core_vif.u2reg,
                funct3,
                funct7
            );

            // Nombre de la instrucción.
            nombre_instr = scoreboard.get_rtype_name(
                funct3,
                funct7
            );

            // Resultado observado directamente desde el DUT.
            observado = core_vif.rmdata;


           
            // PASS
            
            if (observado === esperado) begin

                pruebas_correctas++;

                $display("");
                $display("------------------------------------------------------------");
                $display("Prueba #%0d", numero_prueba);
                $display("Prueba exitosa");
                $display("");

                $display("PC                     : 0x%08h", core_vif.iaddr);
                $display("Instruccion detectada  : %s", nombre_instr);
                $display("Codigo hexadecimal     : 0x%08h", core_vif.xidata);
                $display("");

                $display("Resultado esperado (Scoreboard) : 0x%08h", esperado);
                $display("Resultado observado (DUT)       : 0x%08h", observado);

                $display("------------------------------------------------------------");

            end



            // ERROR
  
            else begin

                errores++;

                $display("");
              	$display("Prueba #%0d", numero_prueba);
                $display("Se detecto una diferencia entre DUT y Scoreboard.");
                $display("");

                $display("PC                     : 0x%08h", core_vif.iaddr);
                $display("Instruccion detectada  : %s", nombre_instr);
                $display("Codigo hexadecimal     : 0x%08h", core_vif.xidata);
                $display("");

                $display("Resultado esperado (Scoreboard) : 0x%08h", esperado);
                $display("Resultado observado (DUT)       : 0x%08h", observado);

                $display("");
                $display("Operandos utilizados:");
                $display("rs1 = 0x%08h", core_vif.u1reg);
                $display("rs2 = 0x%08h", core_vif.u2reg);



            end

        end

    endfunction


    // Reporte final.
  
    function void report();

        $display("");
        $display("-----------------------------------------------");
        $display("Resumen del Checker");
        $display("-----------------------------------------------");

        $display("Instrucciones tipo R revisadas : %0d", instrucciones_r);
        $display("Pruebas correctas             : %0d", pruebas_correctas);
        $display("Errores detectados            : %0d", errores);
        $display("Errores en x0                 : %0d", errores_x0);

        $display("");

        if (instrucciones_r == 0) begin
            $display("Estado final : SIN PRUEBAS");
        end
        else if (errores == 0) begin
            $display("Estado final : PASS");
        end
        else begin
            $display("Estado final : FAIL");
        end

        $display("============================================================");
        $display("");

    endfunction

endclass
