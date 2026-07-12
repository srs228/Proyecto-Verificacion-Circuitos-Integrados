//Paso 1: Crear la clase que extiende de la clase base uvm_monitor
class monitor extends uvm_monitor;

    //Paso 2: Registrarse en la fabrica
    `uvm_component_utils(monitor)

    //Paso 3: Declarar la virtual interface y el puerto de analisis
    // Este monitor pertenece al Agent R (agente pasivo) y observa
    // la salida/respuesta del DUT para alimentar el scoreboard.
    virtual core_if vif;
    uvm_analysis_port #(instr_txn) uvm_analysis_port_mon_obj;
    int unsigned sent_count;
    instr_txn pending_branch_txn;
    bit       pending_branch_valid;

    //Paso 4: Constructor
    function new(string name = "monitor", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    //Paso 5: En build_phase obtenemos la virtual interface y creamos el puerto
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        uvm_analysis_port_mon_obj = new("uvm_analysis_port_mon_obj", this);
        if (!uvm_config_db #(virtual core_if)::get(this, "", "core_vif_obj", vif))
            `uvm_fatal("MON", "No se encontro la virtual interface en config_db (key='core_vif_obj')")
    endfunction

    //Paso 6: En run_phase observamos la respuesta del DUT y publicamos
    // transacciones completas hacia el scoreboard (lado read/response)
    virtual task run_phase(uvm_phase phase);
        instr_txn t;
        bit [6:0] opcode;
        bit       opcode_ok;
        sent_count = 0;
        pending_branch_valid = 1'b0;
        `uvm_info("MON_R", "[MON_R] Monitor de read/response iniciado", UVM_MEDIUM)
        forever begin
            @(posedge vif.clk);
            #1;
            if (!vif.reset_core) begin
                if ($isunknown(vif.xidata) || $isunknown(vif.iaddr))
                    continue;

                opcode = vif.xidata[6:0];
                opcode_ok = (opcode == OPC_RTYPE || opcode == OPC_ITYPE ||
                             opcode == OPC_LUI   || opcode == OPC_AUIPC ||
                             opcode == OPC_LOAD  || opcode == OPC_STYPE ||
                             opcode == OPC_BTYPE || opcode == OPC_JAL   ||
                             opcode == OPC_JALR);

                if (!vif.hlt && !vif.flush && opcode_ok) begin
                    // Completa branch pendiente con el PC de la instruccion actual.
                    if (pending_branch_valid) begin
                        pending_branch_txn.next_pc       = vif.iaddr;
                        pending_branch_txn.next_pc_valid = 1'b1;
                        uvm_analysis_port_mon_obj.write(pending_branch_txn);
                        sent_count++;
                        pending_branch_valid = 1'b0;
                    end

                    t = instr_txn::type_id::create("mon_txn");
                    t.pc            = vif.iaddr;
                    t.instr         = vif.xidata;
                    t.rs1_val       = vif.u1reg;
                    t.rs2_val       = vif.u2reg;
                    t.rd_val_actual = vif.rmdata;
                    t.next_pc       = 32'b0;
                    t.next_pc_valid = 1'b0;
                    t.mem_addr      = 32'b0;
                    t.mem_wdata     = 32'b0;
                    t.mem_valid     = 1'b0;
                    t.is_last       = 1'b0;

                    if (opcode == OPC_STYPE && vif.dwr) begin
                        t.mem_addr  = vif.daddr;
                        t.mem_wdata = vif.datao;
                        t.mem_valid = 1'b1;
                    end

                    t.decode();

                    // Para BRANCH se difiere la publicacion hasta observar el siguiente retiro.
                    if (opcode == OPC_BTYPE) begin
                        void'($cast(pending_branch_txn, t.clone()));
                        pending_branch_valid = 1'b1;
                    end
                    else begin
                        uvm_analysis_port_mon_obj.write(t);
                        sent_count++;
                    end

                    `uvm_info("MON_R",
                        $sformatf(
                            "[MON_R] Response #%0d: pc=0x%08h instr=0x%08h rd=x%0d rd_val_actual=0x%08h",
                            sent_count, t.pc, t.instr, t.rd, t.rd_val_actual),
                        UVM_HIGH)
                end
            end
        end
    endtask

    virtual function void report_phase(uvm_phase phase);
        `uvm_info("MON_R",
            $sformatf("[MON_R] Total transacciones enviadas al scoreboard: %0d", sent_count),
            UVM_NONE)
    endfunction

endclass
