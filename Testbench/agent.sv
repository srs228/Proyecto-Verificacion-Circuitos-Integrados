//Paso 1: Crear la clase que extiende de la clase base uvm_agent
class agent extends uvm_agent;

    //Paso 2: Registrarse en la fabrica
    `uvm_component_utils(agent)

    //Paso 3: Declarar los sub-componentes del Agent W (agente activo)
    base_sequencer sequencer_obj;
    driver         driver_obj;
    monitor_write  monitor_write_obj;

    //Paso 4: Constructor
    function new(string name = "agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    //Paso 5: En build_phase creamos los sub-componentes
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        sequencer_obj     = base_sequencer::type_id::create("sequencer",       this);
        driver_obj        = driver::type_id::create("driver",                  this);
        monitor_write_obj = monitor_write::type_id::create("monitor_write",    this);
        `uvm_info("AGENT_W", "[AGENT_W] build_phase: secuenciador, driver y monitor_write creados", UVM_MEDIUM)
    endfunction

    //Paso 6: En connect_phase conectamos el driver al secuenciador
    virtual function void connect_phase(uvm_phase phase);
        driver_obj.seq_item_port.connect(sequencer_obj.seq_item_export);
        `uvm_info("AGENT_W", "[AGENT_W] connect_phase: driver conectado al secuenciador", UVM_MEDIUM)
    endfunction

endclass
