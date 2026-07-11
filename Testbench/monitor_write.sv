//Paso 1: Crear la clase que extiende de la clase base uvm_monitor
class monitor_write extends uvm_monitor;

    //Paso 2: Registrarse en la fabrica
    `uvm_component_utils(monitor_write)

    //Paso 3: Declarar la virtual interface y el puerto de analisis
    // Este monitor pertenece al Agent W (agente activo) y observa
    // el lado de entrada/estimulo que llega al DUT.
    virtual core_if vif;
    uvm_analysis_port #(instr_txn) uvm_analysis_port_mon_obj;
    int unsigned sent_count;

    //Paso 4: Constructor
    function new(string name = "monitor_write", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    //Paso 5: En build_phase obtenemos la virtual interface y creamos el puerto
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        uvm_analysis_port_mon_obj = new("uvm_analysis_port_mon_obj", this);
        if (!uvm_config_db #(virtual core_if)::get(this, "", "core_vif_obj", vif))
            `uvm_fatal("MON_W", "No se encontro la virtual interface en config_db (key='core_vif_obj')")
    endfunction

    //Paso 6: En run_phase observamos el lado de write/input y publicamos
    // la transaccion observada hacia subscriber y/o scoreboard.
    virtual task run_phase(uvm_phase phase);
        instr_txn t;
        bit [6:0] opcode;
        bit       opcode_ok;
        sent_count = 0;
        `uvm_info("MON_W", "[MON_W] Monitor de write/input iniciado", UVM_MEDIUM)
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
                    t = instr_txn::type_id::create("mon_w_txn");
                    t.pc            = vif.iaddr;
                    t.instr         = vif.xidata;
                    t.rs1_val       = vif.u1reg;
                    t.rs2_val       = vif.u2reg;
                    t.rd_val_actual = 32'b0;
                    t.next_pc       = 32'b0;
                    t.next_pc_valid = 1'b0;
                    t.mem_addr      = 32'b0;
                    t.mem_wdata     = 32'b0;
                    t.mem_valid     = 1'b0;
                    t.is_last       = 1'b0;
                    t.decode();
                    uvm_analysis_port_mon_obj.write(t);
                    sent_count++;
                    `uvm_info("MON_W",
                        $sformatf(
                            "------------------------------------------------------------\n[MON_W] Estimulo observado #%0d\n  pc=0x%08h  instr=0x%08h\n  opcode=%07b  funct3=%03b  funct7=%07b\n  rd=x%0d  rs1=x%0d (val=0x%08h)  rs2=x%0d (val=0x%08h)\n------------------------------------------------------------",
                            sent_count, t.pc, t.instr,
                            t.opcode, t.funct3, t.funct7,
                            t.rd, t.rs1, t.rs1_val, t.rs2, t.rs2_val
                        ),
                        UVM_NONE)
                end
            end
        end
    endtask

    virtual function void report_phase(uvm_phase phase);
        `uvm_info("MON_W",
            $sformatf("[MON_W] Total transacciones de write/input enviadas: %0d", sent_count),
            UVM_NONE)
    endfunction

endclass
