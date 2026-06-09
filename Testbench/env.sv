// Contenedor jerárquico UVM

class env extends uvm_env;
    // Paso 2: Registrarse en la fábrica
    `uvm_component_utils(env) 

    // Paso 3: Declarar la instancia de los componentes necesarios.
    // NOTA: Tener cuidado con los nombres (clases en los archivos respectivos)
    agent agent_obj; 
    agent_read agent_read_obj; 
    core_scoreboard scoreboard_obj;      
    subscriber subscriber_obj;

    // Paso 4: Crear el constructor
    function new(string name = "EnvOBJ", uvm_component parent = null);
        super.new(name, parent);
    endfunction 

    // Paso 5: En build phase creamos instancias a través de la fábrica
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        agent_obj = agent::type_id::create("AgentOBJ", this);
        agent_read_obj = agent_read::type_id::create("Agent_readOBJ", this);
        
        // Instanciación usando core_scoreboard
        // NOTA: Tener presente el nombre de la clase de esos 2 archivos.
        scoreboard_obj = core_scoreboard#()::type_id::create("ScoreboardOBJ", this);
        subscriber_obj = subscriber::type_id::create("SubscriberOBJ", this);
    endfunction

    function void connect_phase (uvm_phase phase);
        // NOTA: Verificar en agent_read.sv, agent.sv, monitor.sv y monitor_writer.sv 
        // que los nombres de los objetos (monitor_obj, monitor_write_obj) 
        // y puertos (uvm_analysis_port_mon_obj) coincidan exactamente con esto.
        
        agent_read_obj.monitor_obj.uvm_analysis_port_mon_obj.connect(
            scoreboard_obj.uvm_analysis_imp_rdifc_obj);
            
        agent_obj.monitor_write_obj.uvm_analysis_port_mon_obj.connect(
            scoreboard_obj.uvm_analysis_imp_wrifc_obj);
            
        agent_obj.monitor_write_obj.uvm_analysis_port_mon_obj.connect(
            subscriber_obj.analysis_export);
    endfunction 

endclass
