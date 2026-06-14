module top;

    logic clk;
    logic reset;

    wire uart_txd;
    wire [31:0] led;
    wire [31:0] iport_nc;
    wire [31:0] oport_nc;
    wire [3:0] debug;

    // Interfaz compartida entre DUT y scoreboard (verifica todas las transacciones)
    core_if core_vif(clk);

    // Instanciar el módulo de aserciones
    aserciones mis_aserciones_obj(.vif(core_vif));


    // 1. Clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end


    // 2. Reset inicial
    initial begin
        reset = 1;

        wait (core_vif.mem_gen_done === 1'b1);
        $readmemh("darksocv.mem", dut.bram0.MEM, 0);
        $display("[TB] Loaded %0d words into DUT memory.", core_vif.program_words);

        repeat (10) @(posedge clk);

        reset = 0;
    end


    // 3. DUT
    darksocv dut (
        .XCLK(clk),
        .XRES(reset),
        .UART_RXD(1'b1),
        .UART_TXD(uart_txd),
        .LED(led),
        .IPORT(32'b0),
        .OPORT(oport_nc),
        .DEBUG(debug)
    );


    // 4. Conexión jerárquica DUT a interfaz
    assign core_vif.reset_core = dut.bridge0.core0.XRES;
    assign core_vif.iaddr      = dut.bridge0.core0.IADDR;

    assign core_vif.x0 = dut.bridge0.core0.REGS[0];

    assign core_vif.r_type = dut.bridge0.core0.RCC;
    assign core_vif.hlt    = dut.bridge0.core0.HLT;
    assign core_vif.flush  = dut.bridge0.core0.FLUSH;

    assign core_vif.xidata = dut.bridge0.core0.XIDATA;
    assign core_vif.rd     = dut.bridge0.core0.DPTR;
    assign core_vif.rs1    = dut.bridge0.core0.S1PTR;
    assign core_vif.rs2    = dut.bridge0.core0.S2PTR;

    assign core_vif.fct3 = dut.bridge0.core0.FCT3;
    assign core_vif.fct7 = dut.bridge0.core0.FCT7;

    assign core_vif.u1reg  = dut.bridge0.core0.U1REG;
    assign core_vif.u2reg  = dut.bridge0.core0.U2REG;
    assign core_vif.rmdata = dut.bridge0.core0.RMDATA;


    // 5. Bloque initial de configuración y arranque UVM
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, top);

        // a. Subimos la interfaz a la base de datos de UVM
        // Esto reemplaza tener que pasar la interfaz como argumento a las clases
        uvm_config_db #(virtual core_if)::set(null, "", "core_vif_obj", core_vif);

        // b. Arrancamos UVM ejecutando el test principal
        // UVM tomará el control a partir de aquí
        run_test("base_test"); 
    end

endmodule

