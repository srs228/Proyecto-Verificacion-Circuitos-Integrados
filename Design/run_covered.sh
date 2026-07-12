#!/usr/bin/env bash
#
# run_covered.sh - Verificacion estructural (cobertura de codigo) del SoC
# darksocv usando Covered 0.7.10 sobre el testbench Verilog plano dark_top_tb.
#
# Uso:
#   chmod +x run_covered.sh   # solo la primera vez
#   ./run_covered.sh
#
set -e
cd "$(dirname "$0")"

# ---------------------------------------------------------------------------
# Fuentes del DUT.
# OJO: config.vh NO se lista aqui. Es un archivo `include (header), asi que
#      su carpeta se pasa con -I . tanto a iverilog como a covered.
# ---------------------------------------------------------------------------
DUT_SRC="darksocv.v darkpll.v darkbridge.v darkriscv.v darkram.v darkio.v darkuart.v"

# ---------------------------------------------------------------------------
# 1) Simular con Icarus Verilog para generar el VCD que consumira Covered.
# ---------------------------------------------------------------------------
echo ">> [1/3] Simulando con Icarus Verilog para generar dump.vcd ..."
iverilog -I . -s dark_top_tb -o dark_sim.out dark_top_tb.v $DUT_SRC
vvp dark_sim.out

# ---------------------------------------------------------------------------
# 2) Puntuar cobertura con Covered.
#    -t darksocv          -> modulo a instrumentar (el DUT, no el testbench)
#    -i dark_top_tb.dut   -> ruta jerarquica de ese modulo dentro del VCD
#    -I .                 -> carpeta donde encontrar config.vh
# ---------------------------------------------------------------------------
echo ">> [2/3] Puntuando cobertura con Covered ..."
covered score \
    -t darksocv -i dark_top_tb.dut \
    -I . \
    -v darksocv.v -v darkpll.v -v darkbridge.v -v darkriscv.v \
    -v darkram.v -v darkio.v -v darkuart.v \
    -vcd dump.vcd \
    -o darksocv.cdd

# ---------------------------------------------------------------------------
# 3) Reporte resumen por pantalla (usa 'covered report -d v' para detalle).
# ---------------------------------------------------------------------------
echo ">> [3/3] Reporte de cobertura:"
covered report -d s darksocv.cdd
