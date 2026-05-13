class core_monitor;

    virtual core_if core_vif;
    mailbox #(instr_txn) mbx;

    int unsigned sent_to_scoreboard;

    function new(virtual core_if core_vif, mailbox #(instr_txn) mbx);
        this.core_vif = core_vif;
        this.mbx = mbx;
        this.sent_to_scoreboard = 0;
    endfunction

    task run();
        instr_txn t;
        bit [6:0] opcode;

        forever begin
            @(posedge core_vif.clk);
            #1;

            if (!core_vif.reset_core) begin
                opcode = core_vif.xidata[6:0];

                if ((opcode == 7'b0110011) &&
                    !core_vif.hlt &&
                    !core_vif.flush) begin

                    t = new();
                    t.pc            = core_vif.iaddr;
                    t.instr         = core_vif.xidata;
                    t.rs1_val       = core_vif.u1reg;
                    t.rs2_val       = core_vif.u2reg;
                    t.rd_val_actual = core_vif.rmdata;

                    mbx.put(t);
                    sent_to_scoreboard++;
                end
            end
        end
    endtask

    function void report();
        $display("-------------------- Resumen del Monitor --------------------");
        $display("Transacciones enviadas al scoreboard : %0d", sent_to_scoreboard);
        $display("-------------------------------------------------------------");
    endfunction

endclass
