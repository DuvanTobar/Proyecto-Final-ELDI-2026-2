`timescale 1ns / 1ps
`default_nettype none

module tb_tile_map_memory;

    reg        clk;
    reg        we;
    reg  [8:0] fsm_addr;
    reg  [1:0] fsm_data_in;
    wire [1:0] fsm_data_out;
    reg  [8:0] vga_addr;
    wire [1:0] vga_data_out;

    integer errors;
    integer k;

    tile_map_memory dut (
        .clk(clk),
        .we(we),
        .fsm_addr(fsm_addr),
        .fsm_data_in(fsm_data_in),
        .fsm_data_out(fsm_data_out),
        .vga_addr(vga_addr),
        .vga_data_out(vga_data_out)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("dump_ram.vcd");
        $dumpvars(0, tb_tile_map_memory);

        errors      = 0;
        we          = 1'b0;
        fsm_addr    = 9'd0;
        fsm_data_in = 2'b00;
        vga_addr    = 9'd0;

        @(posedge clk);
        for (k = 0; k < 512; k = k + 1) begin
            fsm_addr    = k[8:0];
            fsm_data_in = k[1:0];
            we          = 1'b1;
            @(posedge clk);
        end
        we = 1'b0;
        #1;

        for (k = 0; k < 512; k = k + 1) begin
            fsm_addr = k[8:0];
            vga_addr = 9'd511 - k[8:0];
            #1;
            if (fsm_data_out !== k[1:0]) begin
                $display("FAIL [RAM Puerto A]: addr=%0d esperado=%b obtenido=%b", k, k[1:0], fsm_data_out);
                errors = errors + 1;
            end
            if (vga_data_out !== (9'd511 - k[8:0])) begin
                $display("FAIL [RAM Puerto B]: addr=%0d esperado=%b obtenido=%b", 511 - k, (511 - k) & 2'b11, vga_data_out);
                errors = errors + 1;
            end
        end

        fsm_addr    = 9'd100;
        fsm_data_in = 2'b11;
        we          = 1'b0;
        @(posedge clk);
        #1;
        if (fsm_data_out !== 2'b00) begin
            $display("FAIL [RAM WE=0]: Se sobrescribio addr=100 con we=0.");
            errors = errors + 1;
        end else begin
            $display("PASS [RAM WE=0]: Proteccion de escritura correcta.");
        end

        fsm_addr    = 9'd250;
        fsm_data_in = 2'b10;
        vga_addr    = 9'd10;
        we          = 1'b1;
        @(posedge clk);
        we = 1'b0;
        #1;
        if (fsm_data_out !== 2'b10 || vga_data_out !== 2'b10) begin
            $display("FAIL [RAM Dual-Port]: Lectura/escritura simultanea incorrecta.");
            errors = errors + 1;
        end else begin
            $display("PASS [RAM Dual-Port]: Acceso simultaneo verificado.");
        end

        if (errors == 0)
            $display("RESULTADO FINAL RAM: TODAS LAS PRUEBAS PASARON (0 ERRORES).");
        else
            $display("RESULTADO FINAL RAM: SE DETECTARON %0d ERRORES.", errors);

        $finish;
    end
