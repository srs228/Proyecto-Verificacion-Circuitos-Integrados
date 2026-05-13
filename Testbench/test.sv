program testcase(core_if core_vif);

    env env_obj;
    int unsigned drain_cycles;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);

        env_obj = new(core_vif);

        env_obj.reset();
        env_obj.build_program(120);
        env_obj.start_components();

        wait (core_vif.reset_core === 1'b0);

        drain_cycles = (core_vif.program_words * 12) + 200;
        repeat (drain_cycles) @(posedge core_vif.clk);

        env_obj.report();

        $display("[FIN] Simulacion terminada.");
        $finish;
    end

endprogram
