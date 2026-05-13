/*  Fabiola Munoz
    Maria Fernanda Retana
    Sebastian Rojas */


module testbench;

    logic clk;
    logic reset;

    wire uart_txd;
    wire [3:0] led;
    wire [3:0] debug;

    // Interfaz compartida entre DUT, scoreboard y checker
    core_if core_vif(clk);

    // Mailbox requerido por el constructor del scorebard
    mailbox #(instr_txn) mbx;

    // Componentes de verificación
    core_scoreboard scoreboard;
    core_checker chk;


    // 1. Clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end


    // 2. Reset inicial
    initial begin
        reset = 1;
        #100;
        reset = 0;
    end


    // 3. DUT
    darksocv dut (
        .XCLK(clk),
        .XRES(reset),
        .UART_RXD(1'b1),
        .UART_TXD(uart_txd),
        .LED(led),
        .DEBUG(debug)
    );


    // 4. Conexión jerárquica DUT a interfaz
    assign core_vif.reset_core = dut.core0.XRES;
    assign core_vif.iaddr      = dut.core0.IADDR;

    assign core_vif.x0 = dut.core0.REGS[0];

    assign core_vif.r_type = dut.core0.RCC;
    assign core_vif.hlt    = dut.core0.HLT;
    assign core_vif.flush  = dut.core0.FLUSH;

    assign core_vif.xidata = dut.core0.XIDATA;
    assign core_vif.rd     = dut.core0.DPTR;
    assign core_vif.rs1    = dut.core0.S1PTR;
    assign core_vif.rs2    = dut.core0.S2PTR;

    assign core_vif.fct3 = dut.core0.FCT3;
    assign core_vif.fct7 = dut.core0.FCT7;

    assign core_vif.u1reg  = dut.core0.U1REG;
    assign core_vif.u2reg  = dut.core0.U2REG;
    assign core_vif.rmdata = dut.core0.RMDATA;


    // 5. Crear y correr el checker
    initial begin
        mbx = new();

        scoreboard = new(mbx);
        chk        = new(core_vif, scoreboard);

        fork
            chk.run();
        join_none
    end


   //6. Corre simulacion
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, testbench);

        #50000;

        if (scoreboard != null) begin
            scoreboard.report();
        end

        if (chk != null) begin
            chk.report();
        end

        $display("[FIN] Simulacion terminada.");
        $finish;
    end

endmodule
