`timescale 1ns / 1ps
`default_nettype none

module tb_snake_logic_fsm;

    reg         clk_100mhz;
    reg         rst_n;
    reg         btn_up;
    reg         btn_down;
    reg         btn_left;
    reg         btn_right;
    reg         btn_start;

    wire        we;
    wire [8:0]  fsm_addr;
    wire [1:0]  fsm_data_in;
    wire [1:0]  fsm_data_out;
    wire [1:0]  global_state;
    wire [19:0] score_bcd;

    reg [1:0] mock_ram [0:511];
    always @(posedge clk_100mhz) begin
        if (we) mock_ram[fsm_addr] <= fsm_data_in;
    end
    assign fsm_data_out = mock_ram[fsm_addr];

    integer errors;
    reg [8:0] next_cell_addr;

    snake_logic_fsm #(
        .DEBOUNCE_MAX(20'd4),
        .TICK_MAX(25'd30)
    ) dut (
        .clk_100mhz(clk_100mhz),
        .rst_n(rst_n),
        .btn_up(btn_up),
        .btn_down(btn_down),
        .btn_left(btn_left),
        .btn_right(btn_right),
        .btn_start(btn_start),
        .we(we),
        .fsm_addr(fsm_addr),
        .fsm_data_in(fsm_data_in),
        .fsm_data_out(fsm_data_out),
        .global_state(global_state),
        .score_bcd(score_bcd)
    );

    initial clk_100mhz = 1'b0;
    always #5 clk_100mhz = ~clk_100mhz;

    task press_btn;
        input [2:0] sel;
        begin
            case (sel)
                3'd0: btn_right = 1'b1;
                3'd1: btn_left  = 1'b1;
                3'd2: btn_down  = 1'b1;
                3'd3: btn_up    = 1'b1;
                3'd4: btn_start = 1'b1;
            endcase
            repeat (10) @(posedge clk_100mhz);
            btn_right = 1'b0;
            btn_left  = 1'b0;
            btn_down  = 1'b0;
            btn_up    = 1'b0;
            btn_start = 1'b0;
            repeat (10) @(posedge clk_100mhz);
        end
    endtask

    initial begin
        $dumpfile("dump_fsm.vcd");
        $dumpvars(0, tb_snake_logic_fsm);

        errors    = 0;
        rst_n     = 1'b0;
        btn_up    = 1'b0;
        btn_down  = 1'b0;
        btn_left  = 1'b0;
        btn_right = 1'b0;
        btn_start = 1'b0;

        repeat (8) @(posedge clk_100mhz);
        rst_n = 1'b1;
        repeat (8) @(posedge clk_100mhz);

        if (global_state !== 2'b00 || score_bcd !== 20'd0) begin
            $display("FAIL [FSM 1]: Reset incorrecto.");
            errors = errors + 1;
        end else begin
            $display("PASS [FSM 1]: Estado inicial S_MENU y score=00000.");
        end

        press_btn(3'd4);
        repeat (550) @(posedge clk_100mhz);

        if (global_state !== 2'b01 || mock_ram[{4'd7, 5'd5}] !== 2'b01) begin
            $display("FAIL [FSM 2]: Inicializacion de partida fallida.");
            errors = errors + 1;
        end else begin
            $display("PASS [FSM 2]: Tablero limpio y cabeza inicial en (5,7).");
        end

        press_btn(3'd1);
        if (dut.next_dir == 2'b10) begin
            $display("FAIL [FSM 3]: Se permitio giro inverso de 180 grados (RIGHT -> LEFT).");
            errors = errors + 1;
        end else begin
            $display("PASS [FSM 3]: Bloqueo de giro inverso de 180 grados verificado.");
        end

        press_btn(3'd2);
        if (dut.next_dir !== 2'b01) begin
            $display("FAIL [FSM 4]: Giro valido hacia abajo (DIR_DOWN) no registrado.");
            errors = errors + 1;
        end else begin
            $display("PASS [FSM 4]: Cambio de direccion a DIR_DOWN registrado.");
        end

        wait (dut.state == 5'd14);
        next_cell_addr = {dut.head_y[3:0] + 4'd1, dut.head_x[4:0]};
        mock_ram[next_cell_addr] = 2'b10;
        repeat (45) @(posedge clk_100mhz);

        if (score_bcd !== 20'h00100) begin
            $display("FAIL [FSM 5]: Puntaje tras comer manzana esperado=00100, obtenido=%h", score_bcd);
            errors = errors + 1;
        end else begin
            $display("PASS [FSM 5]: Consumo de manzana e incremento BCD (+100) verificado.");
        end

        wait (dut.state == 5'd14);
        next_cell_addr = {dut.head_y[3:0] + 4'd1, dut.head_x[4:0]};
        mock_ram[next_cell_addr] = 2'b11;
        repeat (45) @(posedge clk_100mhz);

        if (global_state !== 2'b10) begin
            $display("FAIL [FSM 6]: Colision con veneno (2'b11) no disparo GAME OVER.");
            errors = errors + 1;
        end else begin
            $display("PASS [FSM 6]: Colision con veneno y transicion a S_GAME_OVER verificada.");
        end

        if (errors == 0)
            $display("RESULTADO FINAL FSM: TODAS LAS PRUEBAS PASARON (0 ERRORES).");
        else
            $display("RESULTADO FINAL FSM: SE DETECTARON %0d ERRORES.", errors);

        $finish;
    end

endmodule
