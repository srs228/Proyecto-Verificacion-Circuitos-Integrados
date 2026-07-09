module aserciones (
    core_if vif
);

    // Aserción 1: x0 siempre debe ser cero fuera de reset
    property p_x0_siempre_cero;
        @(posedge vif.clk) disable iff (vif.reset_core)
        (vif.x0 == 32'b0);
    endproperty
    asercion_x0: assert property (p_x0_siempre_cero)
        else $error("Fallo A1: x0 no es cero en %0t", $time);


    // Aserción 2: Reset limpia PC/iaddr
    property p_reset_limpia_pc;
        @(posedge vif.clk)
        (vif.reset_core) |=> (vif.iaddr == 32'b0);
    endproperty
    asercion_reset: assert property (p_reset_limpia_pc)
        else $error("Fallo A2: iaddr no es 0 despues de reset en %0t", $time);


    // Aserción 3: iaddr no debe ser X fuera de reset
    property p_iaddr_valido;
        @(posedge vif.clk) disable iff (vif.reset_core)
        !$isunknown(vif.iaddr);
    endproperty
    asercion_3: assert property (p_iaddr_valido)
        else $error("Fallo A3: iaddr es X en %0t", $time);


    // Aserción 4: PC alineado a palabra
    property p_iaddr_alineado;
        @(posedge vif.clk) disable iff (vif.reset_core)
        (vif.iaddr[1:0] == 2'b00);
    endproperty
    asercion_4: assert property (p_iaddr_alineado)
        else $error("Fallo A4: iaddr no esta alineado en %0t", $time);


    // Aserción 5: instrucción no desconocida
    property p_xidata_valido;
        @(posedge vif.clk) disable iff (vif.reset_core)
        !$isunknown(vif.xidata);
    endproperty
    asercion_5: assert property (p_xidata_valido)
        else $error("Fallo A5: xidata es X en %0t", $time);


    // Aserción 6: rd decodificado correctamente
    property p_rd_decode;
        @(posedge vif.clk) disable iff (vif.reset_core)
        (vif.rd == vif.xidata[11:7]);
    endproperty
    asercion_6: assert property (p_rd_decode)
        else $error("Fallo A6: rd mal decodificado en %0t", $time);


    // Aserción 7: rs1 decodificado correctamente
    property p_rs1_decode;
        @(posedge vif.clk) disable iff (vif.reset_core)
        (vif.rs1 == vif.xidata[19:15]);
    endproperty
    asercion_7: assert property (p_rs1_decode)
        else $error("Fallo A7: rs1 mal decodificado en %0t", $time);


    // Aserción 8: rs2 decodificado correctamente
    property p_rs2_decode;
        @(posedge vif.clk) disable iff (vif.reset_core)
        (vif.xidata[6:0] inside {7'b0110011, 7'b0100011, 7'b1100011})
        |-> (vif.rs2 == vif.xidata[24:20]);
    endproperty
    asercion_8: assert property (p_rs2_decode)
        else $error("Fallo A8: rs2 mal decodificado en %0t", $time);


    // Aserción 9: funct3 decodificado correctamente
    property p_fct3_decode;
        @(posedge vif.clk) disable iff (vif.reset_core)
        (vif.xidata[6:0] inside {
            7'b0110011, 7'b0010011, 7'b0000011,
            7'b0100011, 7'b1100011, 7'b1100111
        })
        |-> (vif.fct3 == vif.xidata[14:12]);
    endproperty
    asercion_9: assert property (p_fct3_decode)
        else $error("Fallo A9: fct3 mal decodificado en %0t", $time);


    // Aserción 10: funct7 decodificado para instrucciones R
    property p_fct7_decode_r;
        @(posedge vif.clk) disable iff (vif.reset_core)
        (vif.xidata[6:0] == 7'b0110011)
        |-> (vif.fct7 == vif.xidata[31:25]);
    endproperty
    asercion_10: assert property (p_fct7_decode_r)
        else $error("Fallo A10: fct7 mal decodificado en instruccion R en %0t", $time);


    // Aserción 11: operandos leídos no deben ser X
    property p_operandos_validos;
        @(posedge vif.clk) disable iff (vif.reset_core)
        !$isunknown({vif.u1reg, vif.u2reg});
    endproperty
    asercion_11: assert property (p_operandos_validos)
        else $error("Fallo A11: u1reg/u2reg tienen X en %0t", $time);


    // Aserción 12: rmdata válido en LOAD LW
    property p_rmdata_valido_lw;
        @(posedge vif.clk) disable iff (vif.reset_core)
        (vif.xidata[6:0] == 7'b0000011 && vif.xidata[14:12] == 3'b010)
        |-> !$isunknown(vif.rmdata);
    endproperty
    asercion_12: assert property (p_rmdata_valido_lw)
        else $error("Fallo A12: rmdata es X durante LW en %0t", $time);

endmodule