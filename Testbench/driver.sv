class core_driver;

    virtual core_if core_vif;
    string mem_path;
    int unsigned random_instr_count;

    function new(
        virtual core_if core_vif,
        string mem_path = "darksocv.mem",
        int unsigned random_instr_count = 80
    );
        this.core_vif = core_vif;
        this.mem_path = mem_path;
        this.random_instr_count = random_instr_count;
    endfunction

    task build_and_dump(output logic [31:0] prog[$]);
        core_stimulus stim;

        stim = new();
        stim.build_program(prog, random_instr_count);
        dump_mem_file(prog);

        core_vif.mem_gen_done = 1'b1;
        core_vif.program_words = prog.size();

        $display("[DRV] Generated %0d instructions in %s", prog.size(), mem_path);
    endtask

    task dump_mem_file(input logic [31:0] prog[$]);
        integer fd;
        int unsigned i;

        fd = $fopen(mem_path, "w");
        if (fd == 0) begin
            $fatal(1, "[DRV] Could not open %s for writing", mem_path);
        end

        for (i = 0; i < prog.size(); i++) begin
            $fdisplay(fd, "%08x", prog[i]);
        end

        $fclose(fd);
    endtask

endclass
