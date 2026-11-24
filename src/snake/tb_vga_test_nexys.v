`timescale 1ns / 1ps
`default_nettype none

module tb_vga_test_nexys;

    reg        clk_100mhz;
    reg        rst_n;
    reg        btn_up;
    reg        btn_down;
    reg        btn_left;
    reg        btn_right;
    reg        btn_start;

    wire [3:0] VGA_R;
    wire [3:0] VGA_G;
    wire [3:0] VGA_B;
    wire       VGA_HS;
    wire       VGA_VS;

    integer errors;
    integer idx;
    integer food_count;
    integer poison_count;
    reg [8:0] food_pos;
    reg [8:0] poison_pos;
    reg [4:0] dx_f, dx_h;
    reg [3:0] dy_f, dy_h;

    vga_test_nexys #(
        .DEBOUNCE_MAX(20'd5),
        .TICK_MAX(25'd40)
    ) dut (
        .clk_100mhz(clk_100mhz),
        .rst_n(rst_n),
        .btn_up(btn_up),
        .btn_down(btn_down),
        .btn_left(btn_left),
        .btn_right(btn_right),
        .btn_start(btn_start),
        .VGA_R(VGA_R),
        .VGA_G(VGA_G),
        .VGA_B(VGA_B),
        .VGA_HS(VGA_HS),
        .VGA_VS(VGA_VS)
    );

    initial clk_100mhz = 1'b0;
    always #5 clk_100mhz = ~clk_100mhz;

    task pulse_start;
        begin
            btn_start = 1'b1;
            repeat (12) @(posedge clk_100mhz);
            btn_start = 1'b0;
            repeat (12) @(posedge clk_100mhz);
        end
    endtask

    task pulse_down;
        begin
            btn_down = 1'b1;
            repeat (12) @(posedge clk_100mhz);
            btn_down = 1'b0;
            repeat (12) @(posedge clk_100mhz);
        end
    endtask

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_vga_test_nexys);

        errors    = 0;
        rst_n     = 1'b0;
        btn_up    = 1'b0;
        btn_down  = 1'b0;
        btn_left  = 1'b0;
        btn_right = 1'b0;
        btn_start = 1'b0;

        repeat (10) @(posedge clk_100mhz);
        rst_n = 1'b1;
        repeat (10) @(posedge clk_100mhz);

        if (dut.global_game_state !== 2'b00) begin
            $display("FAIL [1]: Estado inicial esperado 2'b00, obtenido %b", dut.global_game_state);
            errors = errors + 1;
        end else begin
            $display("PASS [1]: Estado inicial S_MENU (2'b00) correcto.");
        end

        pulse_start();
        repeat (560) @(posedge clk_100mhz);

        if (dut.global_game_state !== 2'b01) begin
            $display("FAIL [2]: Estado de juego esperado 2'b01, obtenido %b", dut.global_game_state);
            errors = errors + 1;
        end else begin
            $display("PASS [2]: Transicion a modo juego (2'b01) correcta.");
        end

        if (dut.grid_ram.memory_array[{4'd7, 5'd5}] !== 2'b01) begin
            $display("FAIL [3]: Cabeza inicial en (5,7) no encontrada en RAM.");
            errors = errors + 1;
        end else begin
            $display("PASS [3]: Cabeza inicial escrita en RAM {y=7, x=5}.");
        end

        food_count   = 0;
        poison_count = 0;
        food_pos     = 9'd0;
        poison_pos   = 9'd0;

        for (idx = 0; idx < 300; idx = idx + 1) begin
            if (dut.grid_ram.memory_array[idx] == 2'b10) begin
                food_count = food_count + 1;
                food_pos   = idx[8:0];
            end
            if (dut.grid_ram.memory_array[idx] == 2'b11) begin
                poison_count = poison_count + 1;
                poison_pos   = idx[8:0];
            end
        end

        if (food_count != 1 || poison_count != 1) begin
            $display("FAIL [4]: Conteo inesperado -> comida=%0d, veneno=%0d", food_count, poison_count);
            errors = errors + 1;
        end else begin
            $display("PASS [4]: Comida en (x=%0d, y=%0d) y Veneno en (x=%0d, y=%0d) generados.",
                     food_pos[4:0], food_pos[8:5], poison_pos[4:0], poison_pos[8:5]);
        end

        dx_f = (poison_pos[4:0] >= food_pos[4:0]) ? (poison_pos[4:0] - food_pos[4:0]) : (food_pos[4:0] - poison_pos[4:0]);
        dy_f = (poison_pos[8:5] >= food_pos[8:5]) ? (poison_pos[8:5] - food_pos[8:5]) : (food_pos[8:5] - poison_pos[8:5]);
        dx_h = (poison_pos[4:0] >= 5'd5) ? (poison_pos[4:0] - 5'd5) : (5'd5 - poison_pos[4:0]);
        dy_h = (poison_pos[8:5] >= 4'd7) ? (poison_pos[8:5] - 4'd7) : (4'd7 - poison_pos[8:5]);

        if (((dx_f < 5'd2) && (dy_f < 4'd2)) || ((dx_h < 5'd2) && (dy_h < 4'd2))) begin
            $display("FAIL [5]: Veneno viola distancia segura respecto a comida o cabeza.");
            errors = errors + 1;
        end else begin
            $display("PASS [5]: Distancia segura de veneno verificada.");
        end

        repeat (100) @(posedge clk_100mhz);
        if (dut.game_fsm.head_x <= 6'sd5) begin
            $display("FAIL [6]: La serpiente no avanzo hacia la derecha. head_x=%0d", dut.game_fsm.head_x);
            errors = errors + 1;
        end else begin
            $display("PASS [6]: Desplazamiento activo verificado (head_x=%0d).", dut.game_fsm.head_x);
        end

        repeat (1000) @(posedge clk_100mhz);
        if (dut.global_game_state !== 2'b10) begin
            $display("FAIL [7]: Se esperaba GAME OVER (2'b10) tras chocar contra muro, estado=%b", dut.global_game_state);
            errors = errors + 1;
        end else begin
            $display("PASS [7]: Colision contra muro y transicion a GAME OVER (2'b10) verificada.");
        end

        pulse_down();
        if (dut.global_game_state !== 2'b11) begin
            $display("FAIL [8]: Se esperaba SCORE SCREEN (2'b11) tras pulsar btn_down, estado=%b", dut.global_game_state);
            errors = errors + 1;
        end else begin
            $display("PASS [8]: Transicion a pantalla SCORE (2'b11) verificada.");
        end

        pulse_start();
        if (dut.global_game_state !== 2'b00) begin
            $display("FAIL [9]: Se esperaba regreso a MENU (2'b00) tras pulsar btn_start, estado=%b", dut.global_game_state);
            errors = errors + 1;
        end else begin
            $display("PASS [9]: Regreso al MENU (2'b00) verificado.");
        end

        repeat (3500) @(posedge clk_100mhz);
        if (VGA_HS !== 1'b0 && VGA_HS !== 1'b1) begin
            $display("FAIL [10]: Senal VGA_HS indefinida.");
            errors = errors + 1;
        end else begin
            $display("PASS [10]: Generacion de sincronismo VGA verificada.");
        end

        if (errors == 0)
            $display("RESULTADO FINAL: TODAS LAS PRUEBAS PASARON EXITOSAMENTE (0 ERRORES).");
        else
            $display("RESULTADO FINAL: SE DETECTARON %0d ERRORES.", errors);

        $finish;
    end

endmodule
