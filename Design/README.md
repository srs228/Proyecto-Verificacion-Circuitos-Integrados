# Verificacion estructural del DUT darksocv con Covered

Cobertura de codigo (line / toggle / combinational / FSM / memory) del SoC
RISC-V **darksocv** usando **Covered**, sobre un testbench Verilog plano
(`dark_top_tb.v`) simulado con **Icarus Verilog**.

## 1. Requisitos (Ubuntu 26.04)

```bash
sudo apt update
sudo apt install -y iverilog build-essential flex bison tcl-dev tk-dev
```

Covered 0.7.10 no esta en apt; se compila desde el codigo fuente. Como es
codigo de 2014, con GCC moderno hay que forzar `-fcommon` (si no, la compilacion
falla con errores del tipo "multiple definition of ..."):

```bash
tar xzf covered-0.7.10.tar.gz && cd covered-0.7.10
./configure CFLAGS="-fcommon"
make
sudo make install
covered -v            # verifica la instalacion
```

Si `./configure` no encuentra Tcl/Tk, pasale las rutas:

```bash
./configure CFLAGS="-fcommon" --with-tcl=/usr/lib/tcl8.6 --with-tk=/usr/lib/tk8.6
```

## 2. Como ejecutar

```bash
chmod +x run_covered.sh    # solo la primera vez
./run_covered.sh
```

El script hace las 3 etapas (simular -> score -> report) y deja:

- `darksocv.cdd` - base de datos de cobertura de Covered.
- `coverage_summary.txt` - resumen por metrica/instancia.
- `coverage_detailed.txt` - reporte detallado.

GUI opcional (si Covered se compilo con Tcl/Tk): `covered report -view darksocv.cdd`.

## 3. Que se mide y que se excluye

- Modulo puntuado: `darksocv` (top del DUT), localizado como `dark_top_tb.dut`
  dentro del VCD.
- Se **excluyen del conteo** (`-e`) `darkpll` (reloj/reset) y `darkram` (memoria),
  para enfocar la cobertura en `darksocv`, `darkbridge`, `darkriscv`, `darkio` y
  `darkuart`. Ambos se siguen compilando (el diseno debe elaborar completo).

## 4. Notas importantes

**Macro SIMULATION.** En `config.vh`, `SIMULATION` solo se activa con
`__ICARUS__` / `MODEL_TECH` / etc. Icarus define `__ICARUS__`, asi que en la
simulacion si existen `$display/$write/$finish`, los puertos `ESIMREQ/ESIMACK`,
etc. Covered **no** define `__ICARUS__`, asi que ve el diseno con `SIMULATION`
apagado; conviene, porque le oculta a Covered las tareas de sistema que su
parser antiguo no digiere. Es consistente (esos puertos desaparecen a la vez),
asi que la elaboracion no se rompe.

**Firmware (`darksocv.mem`).** Para que el core ejecute instrucciones (y la
cobertura no sea trivial), se incluye un programa RV32I minimo que hace un bucle
de operaciones ALU. `darkram.v` se adapto para leerlo desde la raiz del repo
cuando el simulador es Icarus (rama `` `elsif __ICARUS__ ``); las demas ramas
(Vivado/ModelSim) quedan intactas. Para una cobertura mas alta, reemplaza
`darksocv.mem` por el firmware real del proyecto darkriscv.

## 5. Solucion de problemas

**`ERROR! Badly placed token "Show"` (al leer el VCD).** Covered 0.7.10 no sabe
saltar las secciones `$comment ... $end` que el Icarus moderno emite en el VCD
(p.ej. `$comment Show the parameter values. $end`) y aborta con "Badly placed
token". `run_covered.sh` ya lo resuelve: filtra esos `$comment` a un
`dump_covered.vcd` (con `awk`) y a Covered se le pasa ese VCD limpio. No afecta
la cobertura (los `$comment` no llevan cambios de valor).

**Errores de parseo del RTL.** Si el fallo ocurre *antes* de `Scoring VCD
dumpfile` (leyendo los `.v`), los sospechosos tipicos de Covered 0.7.10 son:

1. `darksocv.v`: el arreglo de *nets* `wire [31:0] XATAIMUX [0:3]` (y `XDACKMUX`)
   indexado por variable dentro del port map: `.XXATAI(XATAIMUX[XADDR[31:30]])`.
2. `darkram.v`: la escritura por bytes a un elemento de memoria
   `MEM[idx][hi:lo] <= ...`.

Copia el mensaje exacto que imprima Covered; el arreglo suele ser reescribir esa
construccion a una forma equivalente que el parser acepte (sin cambiar la logica).
