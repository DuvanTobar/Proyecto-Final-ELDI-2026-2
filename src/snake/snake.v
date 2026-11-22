`timescale 1ns / 1ps
`default_nettype none

module vga_test_nexys (
    input  wire       clk_100mhz,
    input  wire       rst_n,      
    input  wire       btn_up,
    input  wire       btn_down,
    input  wire       btn_left,
    input  wire       btn_right,
    input  wire       btn_start,
    output reg  [3:0] VGA_R,      
    output reg  [3:0] VGA_G,      
    output reg  [3:0] VGA_B,      
    output reg        VGA_HS,     
    output reg        VGA_VS      
);

    reg [1:0] clk_div = 0;
    always @(posedge clk_100mhz or negedge rst_n) begin
        if (!rst_n) clk_div <= 2'b0;
        else clk_div <= clk_div + 1'b1;
    end
    wire clk_25mhz = clk_div[1]; 
 
    reg [9:0] hpos = 0;
    reg [9:0] vpos = 0;
 
    always @(posedge clk_25mhz or negedge rst_n) begin
        if (!rst_n) begin
            hpos <= 10'd0;
            vpos <= 10'd0;
        end else begin
            if (hpos == 10'd799) begin
                hpos <= 10'd0;
                if (vpos == 10'd524) vpos <= 10'd0;
                else vpos <= vpos + 1'b1;
            end else begin
                hpos <= hpos + 1'b1;
            end
        end
    end
 
    always @(posedge clk_25mhz) begin
        VGA_HS <= ~((hpos >= 10'd656) && (hpos < 10'd752));
        VGA_VS <= ~((vpos >= 10'd490) && (vpos < 10'd492));
    end
 
    wire video_on = (hpos < 10'd640) && (vpos < 10'd480);

    reg [5:0] frame_cnt = 0;
    always @(negedge VGA_VS or negedge rst_n) begin
        if (!rst_n) frame_cnt <= 6'd0;
        else frame_cnt <= frame_cnt + 1'b1;
    end
    wire blink_on = frame_cnt[4];
    wire [11:0] btn_txt_col = blink_on ? 12'hFFF : 12'hFC0;

    wire [4:0] cell_x = hpos[9:5];
    wire [3:0] cell_y = vpos[8:5];
    wire [8:0] current_vga_addr = {cell_y, cell_x};
    wire [1:0] square_state;

    wire fsm_we;
    wire [8:0] fsm_address;
    wire [1:0] fsm_data_in_wire;
    wire [1:0] fsm_data_out_wire;
    wire [1:0] global_game_state;
    wire [19:0] score_bcd;

    tile_map_memory grid_ram (
        .clk(clk_100mhz),
        .we(fsm_we), 
        .fsm_addr(fsm_address), 
        .fsm_data_in(fsm_data_in_wire), 
        .fsm_data_out(fsm_data_out_wire),
        .vga_addr(current_vga_addr),
        .vga_data_out(square_state)
    );

    snake_logic_fsm game_fsm (
        .clk_100mhz(clk_100mhz),
        .rst_n(rst_n),
        .btn_up(btn_up),       
        .btn_down(btn_down),
        .btn_left(btn_left),
        .btn_right(btn_right),
        .btn_start(btn_start),
        .we(fsm_we),
        .fsm_addr(fsm_address),
        .fsm_data_in(fsm_data_in_wire),
        .fsm_data_out(fsm_data_out_wire),
        .global_state(global_game_state),
        .score_bcd(score_bcd)
    );

    wire [6:0] ui_x = hpos[9:3];
    wire [5:0] ui_y = vpos[8:3];

    reg [11:0] intro_rgb;
    reg [11:0] game_rgb;
    reg [11:0] gameover_rgb;
    reg [11:0] score_rgb;

    function automatic digit_pixel;
        input [3:0] dig;
        input [2:0] dx;
        input [2:0] dy;
        reg seg_a, seg_b, seg_c, seg_d, seg_e, seg_f, seg_g;
        begin
            case (dig)
                4'd0: {seg_a,seg_b,seg_c,seg_d,seg_e,seg_f,seg_g} = 7'b1111110;
                4'd1: {seg_a,seg_b,seg_c,seg_d,seg_e,seg_f,seg_g} = 7'b0110000;
                4'd2: {seg_a,seg_b,seg_c,seg_d,seg_e,seg_f,seg_g} = 7'b1101101;
                4'd3: {seg_a,seg_b,seg_c,seg_d,seg_e,seg_f,seg_g} = 7'b1111001;
                4'd4: {seg_a,seg_b,seg_c,seg_d,seg_e,seg_f,seg_g} = 7'b0110011;
                4'd5: {seg_a,seg_b,seg_c,seg_d,seg_e,seg_f,seg_g} = 7'b1011011;
                4'd6: {seg_a,seg_b,seg_c,seg_d,seg_e,seg_f,seg_g} = 7'b1011111;
                4'd7: {seg_a,seg_b,seg_c,seg_d,seg_e,seg_f,seg_g} = 7'b1110000;
                4'd8: {seg_a,seg_b,seg_c,seg_d,seg_e,seg_f,seg_g} = 7'b1111111;
                4'd9: {seg_a,seg_b,seg_c,seg_d,seg_e,seg_f,seg_g} = 7'b1111011;
                default: {seg_a,seg_b,seg_c,seg_d,seg_e,seg_f,seg_g} = 7'b0000000;
            endcase
            digit_pixel = 1'b0;
            if (dy == 3'd0 && seg_a) digit_pixel = 1'b1;
            if (dy == 3'd3 && seg_g) digit_pixel = 1'b1;
            if (dy == 3'd6 && seg_d) digit_pixel = 1'b1;
            if (dx == 3'd0 && dy <= 3'd3 && seg_f) digit_pixel = 1'b1;
            if (dx == 3'd3 && dy <= 3'd3 && seg_b) digit_pixel = 1'b1;
            if (dx == 3'd0 && dy >= 3'd3 && seg_e) digit_pixel = 1'b1;
            if (dx == 3'd3 && dy >= 3'd3 && seg_c) digit_pixel = 1'b1;
        end
    endfunction

    always @(*) begin
        intro_rgb = ((ui_x[0] ^ ui_y[0]) == 1'b1) ? 12'h013 : 12'h002;

        if ((ui_x >= 7'd1 && ui_x <= 7'd78) && (ui_y >= 6'd1 && ui_y <= 6'd58)) begin
            if (ui_x == 7'd1 || ui_x == 7'd78 || ui_y == 6'd1 || ui_y == 6'd58)
                intro_rgb = 12'h0F6;
        end
        if ((ui_x >= 7'd3 && ui_x <= 7'd76) && (ui_y >= 6'd3 && ui_y <= 6'd56)) begin
            if (ui_x == 7'd3 || ui_x == 7'd76 || ui_y == 6'd3 || ui_y == 6'd56)
                intro_rgb = 12'h084;
        end

        if (ui_y == 6'd8 && ui_x >= 7'd20 && ui_x <= 7'd48)
            intro_rgb = (ui_x == 7'd48) ? 12'h8F0 : 12'h0D3;
        if (ui_y == 6'd8 && ui_x == 7'd55)
            intro_rgb = 12'hF22;

        if (ui_y >= 6'd15 && ui_y <= 6'd23) begin
            if ((ui_y == 6'd15 || ui_y == 6'd19 || ui_y == 6'd23) && (ui_x >= 7'd22 && ui_x <= 7'd26)) intro_rgb = 12'h0F5;
            if ((ui_x == 7'd22 && ui_y <= 6'd19) || (ui_x == 7'd26 && ui_y >= 6'd19)) intro_rgb = 12'h0F5;
            if ((ui_x == 7'd29 || ui_x == 7'd33)) intro_rgb = 12'h0F5;
            if ((ui_x - 7'd29) == (ui_y - 6'd15) && (ui_x >= 7'd29 && ui_x <= 7'd33)) intro_rgb = 12'h0F5;
            if ((ui_y == 6'd15 || ui_y == 6'd19) && (ui_x >= 7'd36 && ui_x <= 7'd40)) intro_rgb = 12'h0F5;
            if (ui_x == 7'd36 || ui_x == 7'd40) intro_rgb = 12'h0F5;
            if (ui_x == 7'd43) intro_rgb = 12'h0F5;
            if ((ui_x + ui_y == 62 || ui_y - ui_x == -24) && (ui_x >= 7'd44 && ui_x <= 7'd47)) intro_rgb = 12'h0F5;
            if ((ui_y == 6'd15 || ui_y == 6'd19 || ui_y == 6'd23) && (ui_x >= 7'd50 && ui_x <= 7'd54)) intro_rgb = 12'h0F5;
            if (ui_x == 7'd50) intro_rgb = 12'h0F5;
        end

        if (ui_x >= 7'd22 && ui_x <= 7'd56 && ui_y >= 6'd34 && ui_y <= 6'd46) begin
            if (ui_x == 7'd22 || ui_x == 7'd56 || ui_y == 6'd34 || ui_y == 6'd46)
                intro_rgb = btn_txt_col;
            else
                intro_rgb = blink_on ? 12'h093 : 12'h041;

            if (ui_y >= 6'd37 && ui_y <= 6'd43) begin
                if ((ui_y == 6'd37 || ui_y == 6'd40 || ui_y == 6'd43) && (ui_x >= 7'd26 && ui_x <= 7'd29)) intro_rgb = btn_txt_col;
                if ((ui_x == 7'd26 && ui_y <= 6'd40) || (ui_x == 7'd29 && ui_y >= 6'd40)) intro_rgb = btn_txt_col;
                if (ui_y == 6'd37 && (ui_x >= 7'd31 && ui_x <= 7'd35)) intro_rgb = btn_txt_col;
                if (ui_x == 7'd33) intro_rgb = btn_txt_col;
                if ((ui_y == 6'd37 || ui_y == 6'd40) && (ui_x >= 7'd37 && ui_x <= 7'd40)) intro_rgb = btn_txt_col;
                if (ui_x == 7'd37 || ui_x == 7'd40) intro_rgb = btn_txt_col;
                if (ui_x == 7'd43) intro_rgb = btn_txt_col;
                if ((ui_y == 6'd37 || ui_y == 6'd40) && (ui_x >= 7'd43 && ui_x <= 7'd46)) intro_rgb = btn_txt_col;
                if (ui_x == 7'd47 && (ui_y == 6'd38 || ui_y == 6'd39)) intro_rgb = btn_txt_col;
                if ((ui_x == 7'd45 && ui_y == 6'd41) || (ui_x == 7'd46 && ui_y == 6'd42) || (ui_x == 7'd47 && ui_y == 6'd43)) intro_rgb = btn_txt_col;
                if (ui_y == 6'd37 && (ui_x >= 7'd49 && ui_x <= 7'd53)) intro_rgb = btn_txt_col;
                if (ui_x == 7'd51) intro_rgb = btn_txt_col;
            end
        end
    end

    always @(*) begin
        if (hpos < 10'd10 || hpos >= 10'd630 || vpos < 10'd10 || vpos >= 10'd470) begin
            game_rgb = 12'h00F;
        end else begin
            case (square_state)
                2'b00:   game_rgb = 12'h000;
                2'b01:   game_rgb = 12'h0F0;
                2'b10:   game_rgb = 12'hF00;
                2'b11:   game_rgb = 12'h808;
                default: game_rgb = 12'h000;
            endcase
        end
    end

    always @(*) begin
        gameover_rgb = ((ui_x[0] ^ ui_y[0]) == 1'b1) ? 12'h300 : 12'h100;

        if ((ui_x >= 7'd1 && ui_x <= 7'd78) && (ui_y >= 6'd1 && ui_y <= 6'd58)) begin
            if (ui_x == 7'd1 || ui_x == 7'd78 || ui_y == 6'd1 || ui_y == 6'd58)
                gameover_rgb = 12'hFA0;
        end
        if ((ui_x >= 7'd3 && ui_x <= 7'd76) && (ui_y >= 6'd3 && ui_y <= 6'd56)) begin
            if (ui_x == 7'd3 || ui_x == 7'd76 || ui_y == 6'd3 || ui_y == 6'd56)
                gameover_rgb = 12'h830;
        end

        if (ui_x >= 7'd22 && ui_x <= 7'd58 && ui_y >= 6'd7 && ui_y <= 6'd27) begin
            if (ui_x == 7'd22 || ui_x == 7'd58 || ui_y == 6'd7 || ui_y == 6'd27)
                gameover_rgb = 12'hF50;
            else
                gameover_rgb = 12'h000;
        end

        if (ui_y >= 6'd9 && ui_y <= 6'd15) begin
            if ((ui_y == 6'd9 || ui_y == 6'd15) && (ui_x >= 7'd29 && ui_x <= 7'd32)) gameover_rgb = 12'hF22;
            if (ui_x == 7'd29) gameover_rgb = 12'hF22;
            if (ui_x == 7'd32 && ui_y >= 6'd12) gameover_rgb = 12'hF22;
            if (ui_y == 6'd12 && (ui_x == 7'd31 || ui_x == 7'd32)) gameover_rgb = 12'hF22;
            if ((ui_y == 6'd9 || ui_y == 6'd12) && (ui_x >= 7'd35 && ui_x <= 7'd38)) gameover_rgb = 12'hF22;
            if (ui_x == 7'd35 || ui_x == 7'd38) gameover_rgb = 12'hF22;
            if (ui_x == 7'd41 || ui_x == 7'd45) gameover_rgb = 12'hF22;
            if ((ui_x == 7'd42 || ui_x == 7'd44) && ui_y == 6'd10) gameover_rgb = 12'hF22;
            if (ui_x == 7'd43 && ui_y == 6'd11) gameover_rgb = 12'hF22;
            if ((ui_y == 6'd9 || ui_y == 6'd12 || ui_y == 6'd15) && (ui_x >= 7'd47 && ui_x <= 7'd50)) gameover_rgb = 12'hF22;
            if (ui_x == 7'd47) gameover_rgb = 12'hF22;
        end

        if (ui_y >= 6'd18 && ui_y <= 6'd24) begin
            if ((ui_y == 6'd18 || ui_y == 6'd24) && (ui_x >= 7'd29 && ui_x <= 7'd32)) gameover_rgb = 12'hFA0;
            if (ui_x == 7'd29 || ui_x == 7'd32) gameover_rgb = 12'hFA0;
            if ((ui_x == 7'd35 || ui_x == 7'd39) && ui_y <= 6'd22) gameover_rgb = 12'hFA0;
            if ((ui_x == 7'd36 || ui_x == 7'd38) && ui_y == 6'd23) gameover_rgb = 12'hFA0;
            if (ui_x == 7'd37 && ui_y == 6'd24) gameover_rgb = 12'hFA0;
            if ((ui_y == 6'd18 || ui_y == 6'd21 || ui_y == 6'd24) && (ui_x >= 7'd41 && ui_x <= 7'd44)) gameover_rgb = 12'hFA0;
            if (ui_x == 7'd41) gameover_rgb = 12'hFA0;
            if (ui_x == 7'd47) gameover_rgb = 12'hFA0;
            if ((ui_y == 6'd18 || ui_y == 6'd21) && (ui_x >= 7'd47 && ui_x <= 7'd50)) gameover_rgb = 12'hFA0;
            if (ui_x == 7'd51 && (ui_y == 6'd19 || ui_y == 6'd20)) gameover_rgb = 12'hFA0;
            if ((ui_x == 7'd49 && ui_y == 6'd22) || (ui_x == 7'd50 && ui_y == 6'd23) || (ui_x == 7'd51 && ui_y == 6'd24)) gameover_rgb = 12'hFA0;
        end

        if (ui_x >= 7'd21 && ui_x <= 7'd57 && ui_y >= 6'd30 && ui_y <= 6'd40) begin
            if (ui_x == 7'd21 || ui_x == 7'd57 || ui_y == 6'd30 || ui_y == 6'd40)
                gameover_rgb = btn_txt_col;
            else
                gameover_rgb = blink_on ? 12'hC50 : 12'h510;

            if (ui_y >= 6'd32 && ui_y <= 6'd38) begin
                if (ui_x == 7'd24) gameover_rgb = btn_txt_col;
                if ((ui_y == 6'd32 || ui_y == 6'd35) && (ui_x >= 7'd24 && ui_x <= 7'd27)) gameover_rgb = btn_txt_col;
                if (ui_x == 7'd28 && (ui_y == 6'd33 || ui_y == 6'd34)) gameover_rgb = btn_txt_col;
                if ((ui_x == 7'd26 && ui_y == 6'd36) || (ui_x == 7'd27 && ui_y == 6'd37) || (ui_x == 7'd28 && ui_y == 6'd38)) gameover_rgb = btn_txt_col;
                if ((ui_y == 6'd32 || ui_y == 6'd35 || ui_y == 6'd38) && (ui_x >= 7'd31 && ui_x <= 7'd34)) gameover_rgb = btn_txt_col;
                if (ui_x == 7'd31) gameover_rgb = btn_txt_col;
                if (ui_y == 6'd32 && (ui_x >= 7'd36 && ui_x <= 7'd40)) gameover_rgb = btn_txt_col;
                if (ui_x == 7'd38) gameover_rgb = btn_txt_col;
                if (ui_x == 7'd42) gameover_rgb = btn_txt_col;
                if ((ui_y == 6'd32 || ui_y == 6'd35) && (ui_x >= 7'd42 && ui_x <= 7'd45)) gameover_rgb = btn_txt_col;
                if (ui_x == 7'd46 && (ui_y == 6'd33 || ui_y == 6'd34)) gameover_rgb = btn_txt_col;
                if ((ui_x == 7'd44 && ui_y == 6'd36) || (ui_x == 7'd45 && ui_y == 6'd37) || (ui_x == 7'd46 && ui_y == 6'd38)) gameover_rgb = btn_txt_col;
                if ((ui_x == 7'd49 || ui_x == 7'd53) && ui_y <= 6'd33) gameover_rgb = btn_txt_col;
                if ((ui_x == 7'd50 || ui_x == 7'd52) && ui_y == 6'd34) gameover_rgb = btn_txt_col;
                if (ui_x == 7'd51 && ui_y >= 6'd35) gameover_rgb = btn_txt_col;
            end
        end

        if (ui_x >= 7'd21 && ui_x <= 7'd57 && ui_y >= 6'd43 && ui_y <= 6'd53) begin
            if (ui_x == 7'd21 || ui_x == 7'd57 || ui_y == 6'd43 || ui_y == 6'd53)
                gameover_rgb = 12'h0CF;
            else
                gameover_rgb = 12'h024;

            if (ui_y >= 6'd45 && ui_y <= 6'd51) begin
                if ((ui_y == 6'd45 || ui_y == 6'd48 || ui_y == 6'd51) && (ui_x >= 7'd25 && ui_x <= 7'd28)) gameover_rgb = 12'hFFF;
                if ((ui_x == 7'd25 && ui_y <= 6'd48) || (ui_x == 7'd28 && ui_y >= 6'd48)) gameover_rgb = 12'hFFF;
                if ((ui_y == 6'd45 || ui_y == 6'd51) && (ui_x >= 7'd31 && ui_x <= 7'd34)) gameover_rgb = 12'hFFF;
                if (ui_x == 7'd31) gameover_rgb = 12'hFFF;
                if ((ui_y == 6'd45 || ui_y == 6'd51) && (ui_x >= 7'd37 && ui_x <= 7'd40)) gameover_rgb = 12'hFFF;
                if (ui_x == 7'd37 || ui_x == 7'd40) gameover_rgb = 12'hFFF;
                if (ui_x == 7'd43) gameover_rgb = 12'hFFF;
                if ((ui_y == 6'd45 || ui_y == 6'd48) && (ui_x >= 7'd43 && ui_x <= 7'd46)) gameover_rgb = 12'hFFF;
                if (ui_x == 7'd47 && (ui_y == 6'd46 || ui_y == 6'd47)) gameover_rgb = 12'hFFF;
                if ((ui_x == 7'd45 && ui_y == 6'd49) || (ui_x == 7'd46 && ui_y == 6'd50) || (ui_x == 7'd47 && ui_y == 6'd51)) gameover_rgb = 12'hFFF;
                if ((ui_y == 6'd45 || ui_y == 6'd48 || ui_y == 6'd51) && (ui_x >= 7'd50 && ui_x <= 7'd53)) gameover_rgb = 12'hFFF;
                if (ui_x == 7'd50) gameover_rgb = 12'hFFF;
            end
        end
    end

    always @(*) begin
        score_rgb = ((ui_x[0] ^ ui_y[0]) == 1'b1) ? 12'h012 : 12'h001;

        if ((ui_x >= 7'd1 && ui_x <= 7'd78) && (ui_y >= 6'd1 && ui_y <= 6'd58)) begin
            if (ui_x == 7'd1 || ui_x == 7'd78 || ui_y == 6'd1 || ui_y == 6'd58)
                score_rgb = 12'h0FF;
        end
        if ((ui_x >= 7'd3 && ui_x <= 7'd76) && (ui_y >= 6'd3 && ui_y <= 6'd56)) begin
            if (ui_x == 7'd3 || ui_x == 7'd76 || ui_y == 6'd3 || ui_y == 6'd56)
                score_rgb = 12'h068;
        end

        if (ui_y >= 6'd10 && ui_y <= 6'd16) begin
            if ((ui_y == 6'd10 || ui_y == 6'd13 || ui_y == 6'd16) && (ui_x >= 7'd24 && ui_x <= 7'd27)) score_rgb = 12'h0FF;
            if ((ui_x == 7'd24 && ui_y <= 6'd13) || (ui_x == 7'd27 && ui_y >= 6'd13)) score_rgb = 12'h0FF;
            if ((ui_y == 6'd10 || ui_y == 6'd16) && (ui_x >= 7'd30 && ui_x <= 7'd33)) score_rgb = 12'h0FF;
            if (ui_x == 7'd30) score_rgb = 12'h0FF;
            if ((ui_y == 6'd10 || ui_y == 6'd16) && (ui_x >= 7'd36 && ui_x <= 7'd39)) score_rgb = 12'h0FF;
            if (ui_x == 7'd36 || ui_x == 7'd39) score_rgb = 12'h0FF;
            if (ui_x == 7'd42) score_rgb = 12'h0FF;
            if ((ui_y == 6'd10 || ui_y == 6'd13) && (ui_x >= 7'd42 && ui_x <= 7'd45)) score_rgb = 12'h0FF;
            if (ui_x == 7'd46 && (ui_y == 6'd11 || ui_y == 6'd12)) score_rgb = 12'h0FF;
            if ((ui_x == 7'd44 && ui_y == 6'd14) || (ui_x == 7'd45 && ui_y == 6'd15) || (ui_x == 7'd46 && ui_y == 6'd16)) score_rgb = 12'h0FF;
            if ((ui_y == 6'd10 || ui_y == 6'd13 || ui_y == 6'd16) && (ui_x >= 7'd49 && ui_x <= 7'd52)) score_rgb = 12'h0FF;
            if (ui_x == 7'd49) score_rgb = 12'h0FF;
        end

        if (ui_x >= 7'd18 && ui_x <= 7'd60 && ui_y >= 6'd21 && ui_y <= 6'd35) begin
            if (ui_x == 7'd18 || ui_x == 7'd60 || ui_y == 6'd21 || ui_y == 6'd35)
                score_rgb = 12'hFC0;
            else
                score_rgb = 12'h000;

            if (ui_y >= 6'd25 && ui_y <= 6'd31) begin
                if (ui_x >= 7'd24 && ui_x <= 7'd27) begin
                    if (digit_pixel(score_bcd[19:16], ui_x - 7'd24, ui_y - 6'd25)) score_rgb = 12'hFF0;
                end
                if (ui_x >= 7'd31 && ui_x <= 7'd34) begin
                    if (digit_pixel(score_bcd[15:12], ui_x - 7'd31, ui_y - 6'd25)) score_rgb = 12'hFF0;
                end
                if (ui_x >= 7'd38 && ui_x <= 7'd41) begin
                    if (digit_pixel(score_bcd[11:8], ui_x - 7'd38, ui_y - 6'd25)) score_rgb = 12'hFF0;
                end
                if (ui_x >= 7'd45 && ui_x <= 7'd48) begin
                    if (digit_pixel(score_bcd[7:4], ui_x - 7'd45, ui_y - 6'd25)) score_rgb = 12'hFF0;
                end
                if (ui_x >= 7'd52 && ui_x <= 7'd55) begin
                    if (digit_pixel(score_bcd[3:0], ui_x - 7'd52, ui_y - 6'd25)) score_rgb = 12'hFF0;
                end
            end
        end

        if (ui_x >= 7'd22 && ui_x <= 7'd56 && ui_y >= 6'd40 && ui_y <= 6'd52) begin
            if (ui_x == 7'd22 || ui_x == 7'd56 || ui_y == 6'd40 || ui_y == 6'd52)
                score_rgb = btn_txt_col;
            else
                score_rgb = blink_on ? 12'h079 : 12'h023;

            if (ui_y >= 6'd43 && ui_y <= 6'd49) begin
                if (ui_x == 7'd27 || ui_x == 7'd31) score_rgb = btn_txt_col;
                if ((ui_x == 7'd28 || ui_x == 7'd30) && ui_y == 6'd44) score_rgb = btn_txt_col;
                if (ui_x == 7'd29 && ui_y == 6'd45) score_rgb = btn_txt_col;
                if ((ui_y == 6'd43 || ui_y == 6'd46 || ui_y == 6'd49) && (ui_x >= 7'd34 && ui_x <= 7'd37)) score_rgb = btn_txt_col;
                if (ui_x == 7'd34) score_rgb = btn_txt_col;
                if (ui_x == 7'd40 || ui_x == 7'd44) score_rgb = btn_txt_col;
                if ((ui_x - 7'd40) == (ui_y - 6'd44) && (ui_x >= 7'd40 && ui_x <= 7'd44)) score_rgb = btn_txt_col;
                if ((ui_x == 7'd47 || ui_x == 7'd50) && ui_y <= 6'd48) score_rgb = btn_txt_col;
                if (ui_y == 6'd49 && (ui_x >= 7'd47 && ui_x <= 7'd50)) score_rgb = btn_txt_col;
            end
        end
    end

    reg [11:0] selected_rgb;

    always @(*) begin
        case (global_game_state)
            2'b00:   selected_rgb = intro_rgb;
            2'b01:   selected_rgb = game_rgb;
            2'b10:   selected_rgb = gameover_rgb;
            2'b11:   selected_rgb = score_rgb;
            default: selected_rgb = 12'h000;
        endcase
    end

    always @(posedge clk_25mhz) begin
        if (video_on) begin
            {VGA_R, VGA_G, VGA_B} <= selected_rgb;
        end else begin
            {VGA_R, VGA_G, VGA_B} <= 12'h000;
        end
    end

endmodule

module snake_logic_fsm (
    input  wire        clk_100mhz,
    input  wire        rst_n,
    input  wire        btn_up, btn_down, btn_left, btn_right,
    input  wire        btn_start, 
    output reg         we,
    output reg  [8:0]  fsm_addr,
    output reg  [1:0]  fsm_data_in,
    input  wire [1:0]  fsm_data_out,
    output reg  [1:0]  global_state,
    output wire [19:0] score_bcd
);

    reg [4:0] btn_sync_0, btn_sync_1;
    always @(posedge clk_100mhz or negedge rst_n) begin
        if (!rst_n) begin
            btn_sync_0 <= 5'b0;
            btn_sync_1 <= 5'b0;
        end else begin
            btn_sync_0 <= {btn_start, btn_up, btn_down, btn_left, btn_right};
            btn_sync_1 <= btn_sync_0;
        end
    end

    reg [19:0] deb_cnt [0:4];
    reg [4:0]  btn_clean = 5'b0;
    reg [4:0]  btn_prev  = 5'b0;
    integer i;

    always @(posedge clk_100mhz or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 5; i = i + 1) deb_cnt[i] <= 20'd0;
            btn_clean <= 5'b0;
            btn_prev  <= 5'b0;
        end else begin
            for (i = 0; i < 5; i = i + 1) begin
                if (btn_sync_1[i] != btn_clean[i]) begin
                    deb_cnt[i] <= deb_cnt[i] + 20'd1;
                    if (deb_cnt[i] == 20'd1_000_000) begin
                        btn_clean[i] <= btn_sync_1[i];
                        deb_cnt[i] <= 20'd0;
                    end
                end else begin
                    deb_cnt[i] <= 20'd0;
                end
            end
            btn_prev <= btn_clean;
        end
    end

    wire start_pressed = (btn_clean[4] && !btn_prev[4]);
    wire down_pressed  = (btn_clean[2] && !btn_prev[2]);
    wire s_up    = btn_clean[3];
    wire s_down  = btn_clean[2];
    wire s_left  = btn_clean[1];
    wire s_right = btn_clean[0];

    reg [24:0] tick_counter = 0;
    wire game_tick = (tick_counter == 25'd15_000_000); 
    always @(posedge clk_100mhz or negedge rst_n) begin
        if (!rst_n || game_tick) tick_counter <= 0;
        else tick_counter <= tick_counter + 1;
    end

    reg [9:0] lfsr = 10'b1010110011; 
    always @(posedge clk_100mhz or negedge rst_n) begin
        if (!rst_n) lfsr <= 10'b1010110011;
        else lfsr <= {lfsr[8:0], lfsr[9] ^ lfsr[6]};
    end

    wire [4:0] rand_x = lfsr[4:0];
    wire [3:0] rand_y = lfsr[8:5];
    wire [4:0] safe_x = (rand_x > 5'd19) ? (rand_x - 5'd12) : rand_x;
    wire [3:0] safe_y = (rand_y > 4'd14) ? (rand_y - 4'd2)  : rand_y;

    localparam DIR_UP = 2'b00, DIR_DOWN = 2'b01, DIR_LEFT = 2'b10, DIR_RIGHT = 2'b11;
    reg [1:0] dir, next_dir;
    reg dir_changed_in_tick;
    
    always @(posedge clk_100mhz or negedge rst_n) begin
        if (!rst_n) begin
            next_dir <= DIR_RIGHT;
            dir_changed_in_tick <= 0;
        end else if (global_state != 2'b01) begin
            next_dir <= DIR_RIGHT;
            dir_changed_in_tick <= 0;
        end else if (game_tick) begin
            dir_changed_in_tick <= 0;
        end else if (!dir_changed_in_tick) begin
            if (s_up && dir != DIR_DOWN && dir != DIR_UP) begin
                next_dir <= DIR_UP;
                dir_changed_in_tick <= 1;
            end else if (s_down && dir != DIR_UP && dir != DIR_DOWN) begin
                next_dir <= DIR_DOWN;
                dir_changed_in_tick <= 1;
            end else if (s_left && dir != DIR_RIGHT && dir != DIR_LEFT) begin
                next_dir <= DIR_LEFT;
                dir_changed_in_tick <= 1;
            end else if (s_right && dir != DIR_LEFT && dir != DIR_RIGHT) begin
                next_dir <= DIR_RIGHT;
                dir_changed_in_tick <= 1;
            end
        end
    end

    reg [3:0] sc_d4, sc_d3, sc_d2, sc_d1, sc_d0;
    assign score_bcd = {sc_d4, sc_d3, sc_d2, sc_d1, sc_d0};

    reg [8:0] snake_body [0:511]; 
    reg [8:0] head_ptr; 
    reg [8:0] tail_ptr; 
    reg [8:0] current_poison_addr;

    localparam S_MENU               = 5'd0,
               S_CLEAR_RAM          = 5'd1,
               S_INIT               = 5'd2,
               S_INIT_STROBE        = 5'd3,
               S_REQ_FOOD           = 5'd4,
               S_WAIT_FOOD_READ     = 5'd5,
               S_CHECK_FOOD         = 5'd6,
               S_FOOD_STROBE        = 5'd7,
               S_ERASE_OLD_POISON   = 5'd8,
               S_ERASE_POISON_STB   = 5'd9,
               S_REQ_POISON         = 5'd10,
               S_WAIT_POISON_READ   = 5'd11,
               S_CHECK_POISON       = 5'd12,
               S_POISON_STROBE      = 5'd13,
               S_WAIT_TICK          = 5'd14,
               S_CALC_NEXT          = 5'd15,
               S_WAIT_READ          = 5'd16,
               S_EVALUATE_COLLISION = 5'd17,
               S_ERASE_TAIL         = 5'd18,
               S_ERASE_TAIL_STB     = 5'd19,
               S_DRAW_HEAD          = 5'd20,
               S_DRAW_HEAD_STB      = 5'd21,
               S_GAME_OVER          = 5'd22,
               S_SCORE_SCREEN       = 5'd23;
    
    reg [4:0] state = S_MENU;
    
    reg signed [5:0] next_x, head_x; 
    reg signed [5:0] next_y, head_y;
    reg just_ate;
    reg initial_spawn;
    reg [8:0] clear_ptr;
    reg [8:0] candidate_addr;

    wire signed [5:0] calc_next_x = (dir == DIR_LEFT) ? (head_x - 1) : ((dir == DIR_RIGHT) ? (head_x + 1) : head_x);
    wire signed [5:0] calc_next_y = (dir == DIR_UP)   ? (head_y - 1) : ((dir == DIR_DOWN)  ? (head_y + 1) : head_y);

    always @(posedge clk_100mhz or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_MENU;
            global_state <= 2'b00;
            we <= 0;
            just_ate <= 0;
            initial_spawn <= 0;
            clear_ptr <= 9'd0;
            {sc_d4, sc_d3, sc_d2, sc_d1, sc_d0} <= 20'd0;
        end else begin
            we <= 0;

            case (state)
                S_MENU: begin
                    global_state <= 2'b00;
                    if (start_pressed) begin
                        clear_ptr <= 9'd0;
                        {sc_d4, sc_d3, sc_d2, sc_d1, sc_d0} <= 20'd0;
                        state <= S_CLEAR_RAM;
                    end
                end

                S_CLEAR_RAM: begin
                    global_state <= 2'b01;
                    fsm_addr <= clear_ptr;
                    fsm_data_in <= 2'b00;
                    we <= 1;
                    if (clear_ptr == 9'd511) state <= S_INIT; 
                    else clear_ptr <= clear_ptr + 1;
                end

                S_INIT: begin
                    head_x <= 6'd5; 
                    head_y <= 6'd7;
                    head_ptr <= 9'd0;   
                    tail_ptr <= 9'd0;
                    dir <= DIR_RIGHT;
                    just_ate <= 0;
                    initial_spawn <= 1;
                    snake_body[0] <= {4'd7, 5'd5}; 
                    fsm_addr <= {4'd7, 5'd5};
                    fsm_data_in <= 2'b01; 
                    state <= S_INIT_STROBE;
                end

                S_INIT_STROBE: begin
                    we <= 1;
                    state <= S_REQ_FOOD;
                end
                
                S_REQ_FOOD: begin
                    candidate_addr <= {safe_y, safe_x};
                    fsm_addr <= {safe_y, safe_x};
                    state <= S_WAIT_FOOD_READ;
                end

                S_WAIT_FOOD_READ: begin
                    state <= S_CHECK_FOOD;
                end

                S_CHECK_FOOD: begin
                    if (fsm_data_out == 2'b00) begin
                        fsm_addr <= candidate_addr;
                        fsm_data_in <= 2'b10;
                        state <= S_FOOD_STROBE;
                    end else begin
                        state <= S_REQ_FOOD;
                    end
                end

                S_FOOD_STROBE: begin
                    we <= 1;
                    if (initial_spawn) begin
                        initial_spawn <= 0;
                        state <= S_REQ_POISON;
                    end else begin
                        state <= S_ERASE_OLD_POISON;
                    end
                end

                S_ERASE_OLD_POISON: begin
                    fsm_addr <= current_poison_addr;
                    fsm_data_in <= 2'b00;
                    state <= S_ERASE_POISON_STB;
                end

                S_ERASE_POISON_STB: begin
                    we <= 1;
                    state <= S_REQ_POISON;
                end

                S_REQ_POISON: begin
                    candidate_addr <= {safe_y, safe_x};
                    fsm_addr <= {safe_y, safe_x};
                    state <= S_WAIT_POISON_READ;
                end

                S_WAIT_POISON_READ: begin
                    state <= S_CHECK_POISON;
                end

                S_CHECK_POISON: begin
                    if (fsm_data_out == 2'b00) begin
                        fsm_addr <= candidate_addr;
                        fsm_data_in <= 2'b11;
                        current_poison_addr <= candidate_addr;
                        state <= S_POISON_STROBE;
                    end else begin
                        state <= S_REQ_POISON;
                    end
                end

                S_POISON_STROBE: begin
                    we <= 1;
                    state <= S_WAIT_TICK;
                end

                S_WAIT_TICK: begin
                    just_ate <= 0; 
                    if (game_tick) begin
                        dir <= next_dir;
                        state <= S_CALC_NEXT;
                    end
                end

                S_CALC_NEXT: begin 
                    next_x <= calc_next_x;
                    next_y <= calc_next_y;

                    if (calc_next_x > 19 || calc_next_x < 0 || calc_next_y > 14 || calc_next_y < 0) begin
                        state <= S_GAME_OVER;
                    end else begin
                        fsm_addr <= {calc_next_y[3:0], calc_next_x[4:0]}; 
                        state <= S_WAIT_READ;
                    end
                end

                S_WAIT_READ: begin
                    state <= S_EVALUATE_COLLISION;
                end

                S_EVALUATE_COLLISION: begin
                    if (fsm_data_out == 2'b11) begin
                        state <= S_GAME_OVER;
                    end else if (fsm_data_out == 2'b01 && ({next_y[3:0], next_x[4:0]} != snake_body[tail_ptr])) begin
                        state <= S_GAME_OVER;
                    end else begin
                        head_x <= next_x; 
                        head_y <= next_y;
                        head_ptr <= head_ptr + 1;
                        snake_body[head_ptr + 1] <= {next_y[3:0], next_x[4:0]};
                        
                        if (fsm_data_out == 2'b10) begin
                            just_ate <= 1;
                            if (sc_d2 == 4'd9) begin
                                sc_d2 <= 4'd0;
                                if (sc_d3 == 4'd9) begin
                                    sc_d3 <= 4'd0;
                                    if (sc_d4 < 4'd9) sc_d4 <= sc_d4 + 4'd1;
                                end else begin
                                    sc_d3 <= sc_d3 + 4'd1;
                                end
                            end else begin
                                sc_d2 <= sc_d2 + 4'd1;
                            end
                            state <= S_DRAW_HEAD;
                        end else begin
                            state <= S_ERASE_TAIL;
                        end
                    end
                end

                S_ERASE_TAIL: begin 
                    fsm_addr <= snake_body[tail_ptr];
                    fsm_data_in <= 2'b00;
                    tail_ptr <= tail_ptr + 1; 
                    state <= S_ERASE_TAIL_STB;
                end

                S_ERASE_TAIL_STB: begin
                    we <= 1;
                    state <= S_DRAW_HEAD;
                end

                S_DRAW_HEAD: begin 
                    fsm_addr <= {head_y[3:0], head_x[4:0]};
                    fsm_data_in <= 2'b01;
                    state <= S_DRAW_HEAD_STB;
                end

                S_DRAW_HEAD_STB: begin
                    we <= 1;
                    if (just_ate) state <= S_REQ_FOOD;
                    else state <= S_WAIT_TICK;
                end

                S_GAME_OVER: begin
                    global_state <= 2'b10;
                    if (start_pressed) begin
                        clear_ptr <= 9'd0;
                        {sc_d4, sc_d3, sc_d2, sc_d1, sc_d0} <= 20'd0;
                        state <= S_CLEAR_RAM;
                    end else if (down_pressed) begin
                        state <= S_SCORE_SCREEN;
                    end
                end

                S_SCORE_SCREEN: begin
                    global_state <= 2'b11;
                    if (start_pressed) begin
                        state <= S_MENU;
                    end
                end

                default: state <= S_MENU;
            endcase
        end
    end
endmodule

module tile_map_memory (
    input  wire       clk,
    input  wire       we,
    input  wire [8:0] fsm_addr,
    input  wire [1:0] fsm_data_in,
    output wire [1:0] fsm_data_out,
    input  wire [8:0] vga_addr,
    output wire [1:0] vga_data_out
);
    reg [1:0] memory_array [511:0];

    always @(posedge clk) begin
        if (we) begin
            memory_array[fsm_addr] <= fsm_data_in;
        end
    end

    assign fsm_data_out = memory_array[fsm_addr];
    assign vga_data_out = memory_array[vga_addr];
endmodule
