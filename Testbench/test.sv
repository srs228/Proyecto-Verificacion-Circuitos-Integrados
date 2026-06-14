//Paso 1: Crear la clase que extiende de la clase base uvm_test
class base_test extends uvm_test;
    //Paso 2: Registrarse en la fábrica
    `uvm_component_utils(base_test)

    //Paso 3: Declarar la instancia de los componentes necesarios  
    env env_obj;

    //Paso 4: Crear el constructor. Esto es casi genérico para todos los componentes
    function new(string name = "base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    //Paso 5: En build phase configuramos asignando a atributos, o creamos instancias
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
    // NOTA: "EnvOBJ" es el nombre de la instancia en la jerarquía UVM.
        env_obj = env::type_id::create("EnvOBJ", this);
    endfunction

    //Paso 6: Opcional imprimir la topología.
    virtual function void end_of_elaboration_phase (uvm_phase phase);
        uvm_top.print_topology ();
    endfunction

    virtual task run_phase (uvm_phase phase);  
        //Se define una secuencia
        base_sequence base_sequence_obj = base_sequence::type_id::create("Secuencia inicial");
        super.run_phase(phase);
        // Debemos levantar una objecion para que el test no termine antes de tiempo
        phase.raise_objection(this);
        
        // NOTA (Secuenciador y Agente): 
        // Revisar en agent.sv y env.sv cómo nombraron las variables.
        base_sequence_obj.start(env_obj.agent_obj.sequencer_obj);
        
        // Esperar suficientes ciclos de reloj para que el DUT salga del reset
        // (10 ciclos) y ejecute todas las instrucciones del programa (~96 palabras
        // x ~2 ciclos c/u). Con un reloj de 10ns (período): 5000 ciclos = 50 us.
        // Esto permite que los monitores observen las transacciones del DUT.
        #50000;
        
        phase.drop_objection(this);
    endtask
endclass
