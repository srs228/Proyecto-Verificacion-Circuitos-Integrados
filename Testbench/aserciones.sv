// ============================================================
// aserciones — Módulo de aserciones SVA
//
// Encapsula las aserciones de la interface en un módulo
// instanciado por top.sv.
// Las aserciones reales están definidas directamente en
// core_if (interface.sv).  Este módulo es el punto de
// instanciación que top.sv espera.
// ============================================================

module aserciones (
    core_if vif
);

    // Las aserciones están definidas en core_if (interface.sv):
    //   asercion_x0, asercion_reset, asercion_iaddr_valido
    // No se necesita lógica adicional aquí.

endmodule
