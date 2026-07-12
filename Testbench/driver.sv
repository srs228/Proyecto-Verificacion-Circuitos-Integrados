//Paso 1: Crear la clase que extiende de la clase base uvm_driver
class driver extends uvm_driver #(instr_txn);

    //Paso 2: Registrarse en la fabrica
    `uvm_component_utils(driver)

    //Paso 3: Declarar la virtual interface y atributos
    virtual core_if vif;
    string       mem_path  = "darksocv.mem";
    logic [31:0] prog[$];
    bit          mem_written;

    //Paso 4: Constructor
    function new(string name = "driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    //Paso 5: En build_phase obtenemos la virtual interface del config_db
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual core_if)::get(this, "", "core_vif_obj", vif))
            `uvm_fatal("DRV", "No se encontro la virtual interface en config_db (key='core_vif_obj')")
    endfunction

    // Inicializacion previa a run_phase.
    virtual function void start_of_simulation_phase(uvm_phase phase);
        super.start_of_simulation_phase(phase);
        prog.delete();
        mem_written       = 1'b0;
        vif.mem_gen_done  = 1'b0;
        vif.program_words = 0;
    endfunction

    //Paso 6: En run_phase recibimos cada item del secuenciador y lo aplicamos
    virtual task run_phase(uvm_phase phase);
        forever begin
            seq_item_port.get_next_item(req);
            req.decode();
            prog.push_back(req.instr);

            if (req.is_last && !mem_written) begin
                dump_mem(prog);
                vif.program_words = prog.size();
                vif.mem_gen_done  = 1'b1;
                mem_written       = 1'b1;
                `uvm_info("DRV",
                    $sformatf("[DRV] Programa escrito desde sequence: %0d instrucciones en %s | mem_gen_done=1",
                              prog.size(), mem_path),
                    UVM_NONE)
            end

            `uvm_info("DRV",
                $sformatf("[DRV] Item recibido #%0d: %s", prog.size(), req.convert2string()),
                UVM_MEDIUM)
            seq_item_port.item_done();
        end
    endtask

    // Funcion auxiliar: escribir la cola de instrucciones en darksocv.mem
    function void dump_mem(input logic [31:0] prog[$]);
        integer fd;
        int unsigned i;
        fd = $fopen(mem_path, "w");
        if (fd == 0)
            `uvm_fatal("DRV", $sformatf("No se pudo abrir %s para escritura", mem_path))
        for (i = 0; i < prog.size(); i++)
            $fdisplay(fd, "%08x", prog[i]);
        $fclose(fd);
    endfunction

endclass
