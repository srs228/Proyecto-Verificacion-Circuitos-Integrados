`include "uvm_macros.svh"
import uvm_pkg::*;

// Orden de compilación UVM:
// 1.  Interface    → core_if
// 2.  instr_txn    → OPC_* localparams + enum instr_type_e + class instr_txn
// 3.  scoreboard   → modelos de referencia + class core_scoreboard
// 4.  stimulus     → class core_stimulus (no-UVM, generador de programa)
// 5.  monitor      → class monitor (fetch, agente pasivo)
// 6.  monitor_write→ class monitor_write (write-back, agente activo)
// 7.  sequencer    → class base_sequencer
// 8.  driver       → class driver
// 9.  sequence     → class base_sequence
// 10. subscriber   → class core_subscriber
// 11. agent_read   → class agent_read (contiene monitor)
// 12. agent        → class agent (contiene sequencer + driver + monitor_write)
// 13. env          → class env
// 14. test         → class base_test
// 15. aserciones   → module aserciones
// 16. top          → module top
`include "interface.sv"
`include "instr_txn.sv"
`include "scoreboard.sv"
`include "stimulus.sv"
`include "monitor.sv"
`include "monitor_write.sv"
`include "sequencer.sv"
`include "driver.sv"
`include "sequence.sv"
`include "subscriber.sv"
`include "agent_read.sv"
`include "agent.sv"
`include "env.sv"
`include "test.sv"
`include "aserciones.sv"
`include "top.sv"
