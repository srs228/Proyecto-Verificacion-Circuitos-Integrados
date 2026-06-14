//Paso 1: Crear la clase que extiende de la clase base uvm_sequencer
class base_sequencer extends uvm_sequencer #(instr_txn);

    //Paso 2: Registrarse en la fábrica
    `uvm_component_utils(base_sequencer)

    //Paso 3: Constructor
    function new(string name = "base_sequencer", uvm_component parent = null);
        super.new(name, parent);
    endfunction

endclass
