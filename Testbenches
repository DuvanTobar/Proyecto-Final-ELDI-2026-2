`timescale 1ns / 1ps

module snake_logic_fsm_tb;
    reg        clk_100mhz = 0;
    reg        rst_n = 0;
    reg        btn_up = 0, btn_down = 0, btn_left = 0, btn_right = 0;
    reg        btn_start = 0;

    wire       we;
    wire [8:0] fsm_addr;
    wire [1:0] fsm_data_in;
    wire [1:0] fsm_data_out;
    wire [1:0] global_state;

    tile_map_memory ram_inst (
        .clk(clk_100mhz),
        .we(we),
        .fsm_addr(fsm_addr),
        .fsm_data_in(fsm_data_in),
        .fsm_data_out(fsm_data_out),
        .vga_addr(9'd0),
        .vga_data_out()
    );

    snake_logic_fsm #(
        .DEBOUNCE_LIMIT(20'd5),
        .TICK_LIMIT(25'd40)
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
        .global_state(global_state)
    );

    always #5 clk_100mhz = ~clk_100mhz; 

    initial begin
        $dumpfile("fsm_waves.vcd");
        $dumpvars(0, snake_logic_fsm_tb);

        #30 rst_n = 1;
        #100;

        btn_start = 1;
        #150;
        btn_start = 0;

        #8000;

        btn_down = 1;
        #200;
        btn_down = 0;
        #6000;

        btn_start = 1;
        #150;
        btn_start = 0;
        #7000;

        $finish;
