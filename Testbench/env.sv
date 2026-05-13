class env;

    virtual core_if core_vif;

    mailbox #(instr_txn) mbx;

    core_scoreboard scoreboard_obj;
    core_checker    checker_obj;
    core_driver     driver_obj;
    core_monitor    monitor_obj;

    logic [31:0] prog_q[$];

    function new(virtual core_if core_vif);
        this.core_vif = core_vif;

        mbx = new();

        scoreboard_obj = new(mbx);
        checker_obj    = new(core_vif, scoreboard_obj);
        driver_obj     = new(core_vif, "darksocv.mem", 120);
        monitor_obj    = new(core_vif, mbx);
    endfunction

    task reset();
        core_vif.mem_gen_done = 1'b0;
        core_vif.program_words = 0;
    endtask

    task build_program(int unsigned random_count = 120);
        driver_obj.random_instr_count = random_count;
        driver_obj.build_and_dump(prog_q);
    endtask

    task start_components();
        fork
            checker_obj.run();
            scoreboard_obj.run();
            monitor_obj.run();
        join_none
    endtask

    function void report();
        if (scoreboard_obj != null) begin
            scoreboard_obj.report();
        end

        if (checker_obj != null) begin
            checker_obj.report();
        end

        if (monitor_obj != null) begin
            monitor_obj.report();
        end
    endfunction

endclass
