/*
 * dark_top_tb.v
 *
 * Top de simulacion minimo para darksocv, escrito en Verilog plano
 * (sin clases SystemVerilog/UVM) para que Covered 0.7.10 lo pueda
 * parsear completo junto con el resto del DUT.
 *
 * Config asumida (config.vh por defecto, sin macro de board):
 *   - SPI       : no definido  -> sin puertos SPI_*
 *   - __SDRAM__ : no definido  -> sin puertos S_*
 *   - __HARVARD__ : definido   -> IDREQ interno queda en 0 (no cache)
 *   - BOARD_CK  : definido (100MHz por config.vh) -> darkpll usa la
 *                 rama "sin PLL real" (CLK=XCLK) al no haber macro
 *                 de vendor (XILINX7CLK/XILINX6CLK/etc.)
 *
 * Flujo de uso:
 *   1) Simular con Icarus Verilog para generar dump.vcd
 *   2) Pasar este archivo + los .v del DUT a "covered score"
 *      usando -t darksocv -i dark_top_tb.dut (ver comandos abajo)
 */

`timescale 1ns / 1ps

module dark_top_tb;

    // ------------------------------------------------------------------
    // señales de estimulo hacia el DUT
    // ------------------------------------------------------------------
    reg         XCLK;
    reg         XRES;
    reg         UART_RXD;
    wire        UART_TXD;
    wire [31:0] LED;
    reg  [31:0] IPORT;
    wire [31:0] OPORT;
    wire [3:0]  DEBUG;

    // ------------------------------------------------------------------
    // instancia del DUT (darksocv = SoC completo)
    // ------------------------------------------------------------------
    darksocv dut
    (
        .XCLK     (XCLK),
        .XRES     (XRES),
        .UART_RXD (UART_RXD),
        .UART_TXD (UART_TXD),
        .LED      (LED),
        .IPORT    (IPORT),
        .OPORT    (OPORT),
        .DEBUG    (DEBUG)
    );

    // ------------------------------------------------------------------
    // reloj: periodo arbitrario, solo interesa que conmute
    // ------------------------------------------------------------------
    initial XCLK = 1'b0;
    always #5 XCLK = ~XCLK; // ~100MHz

    // ------------------------------------------------------------------
    // reset: XRES activo-alto sostenido y luego liberado.
    // darkpll (rama sin PLL de vendor) necesita ~128 ciclos de XCLK
    // para bajar IRES y otros ~128 para bajar DRES antes de que el
    // RES interno se libere, asi que dejamos margen amplio.
    // ------------------------------------------------------------------
    initial
    begin
        XRES     = 1'b1;
        UART_RXD = 1'b1;   // linea UART en reposo
        IPORT    = 32'h0000_0000;

        #200;              // XRES sostenido
        XRES = 1'b0;

        #4000;             // margen para que RES interno se libere
    end

    // ------------------------------------------------------------------
    // estimulo simple en IPORT para generar actividad de toggle
    // en la logica de entrada del SoC
    // ------------------------------------------------------------------
    always #37 IPORT = IPORT + 32'h1;

    // ------------------------------------------------------------------
    // volcado VCD para Covered
    // ------------------------------------------------------------------
    initial
    begin
        $dumpfile("dump.vcd");
        $dumpvars(0, dark_top_tb);
    end

    // ------------------------------------------------------------------
    // duracion de la simulacion
    // ------------------------------------------------------------------
    initial
    begin
        #50000;
        $display("dark_top_tb: fin de simulacion");
        $finish;
    end

endmodule