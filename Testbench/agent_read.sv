//Paso 1: Crear la clase que extiende de la clase base uvm_agent
class agent_read extends uvm_agent;

    //Paso 2: Registrarse en la fabrica
    `uvm_component_utils(agent_read)

    //Paso 3: Declarar el monitor del Agent R (agente pasivo)
    monitor monitor_obj;

    //Paso 4: Constructor
    function new(string name = "agent_read", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    //Paso 5: En build_phase creamos el monitor
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        monitor_obj = monitor::type_id::create("monitor", this);
        `uvm_info("AGENT_R", "[AGENT_R] build_phase: monitor de respuesta creado", UVM_MEDIUM)
    endfunction

endclass
