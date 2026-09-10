module data_sampling #(parameter Prescale_Width = 5) (
    input wire clk,
    input wire rst_n,
    input wire RX_IN,
    input wire dat_samp_en,
    input wire [Prescale_Width-1:0] edge_cnt,
    input wire [Prescale_Width-1:0] Prescale,
    output reg sampled_bit
);

reg [2:0] samples;
wire [Prescale_Width-1:0] half_point;

assign half_point = (Prescale >> 1);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        samples <= 3'b000;
        sampled_bit <= 1'b0;
    end
    else if (dat_samp_en) begin
        if (edge_cnt == half_point - 1) begin
            samples[0] <= RX_IN;
        end
        else if (edge_cnt == half_point) begin
            samples[1] <= RX_IN;
        end
        else if (edge_cnt == half_point + 1) begin
            samples[2] <= RX_IN;
            sampled_bit <= (samples[0] & samples[1]) | (samples[1] & samples[2]) | (samples[0] & samples[2]);
        end
    end
end
endmodule
//--------------------------------------------------------//
//--------------------------------------------------------//
//--------------------------------------------------------//
module edge_bit_counter #(parameter Prescale_Width = 5, bit_cnt_Width = 4) (
    input wire clk,
    input wire rst_n,
    input wire enable,
    input wire [Prescale_Width-1:0] Prescale,
    output reg [Prescale_Width-1:0] edge_cnt,
    output reg [bit_cnt_Width-1:0] bit_cnt
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        edge_cnt <= 0;
        bit_cnt <= 0;
    end 
    else if (enable) begin
        if (edge_cnt == Prescale - 1) begin
            edge_cnt <= 0;
            bit_cnt <= bit_cnt + 1;
        end else begin
            edge_cnt <= edge_cnt + 1;
        end
    end 
    else begin
        edge_cnt <= 0;
        bit_cnt <= 0;
    end
end
endmodule
//--------------------------------------------------------//
//--------------------------------------------------------//
//--------------------------------------------------------//
module deserializer #(parameter WIDTH = 8, Prescale_Width = 5) (
    input wire clk,
    input wire rst_n,
    input wire deser_en,
    input wire sampled_bit,
    input wire [Prescale_Width-1:0] edge_cnt,
    input wire [Prescale_Width-1:0] Prescale,
    output reg [WIDTH-1:0] P_DATA
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        P_DATA <= 0;
    end 
    else if (deser_en && (edge_cnt == Prescale - 1)) begin
        P_DATA <= {sampled_bit, P_DATA[WIDTH-1:1]};
    end
end
endmodule
//--------------------------------------------------------//
//--------------------------------------------------------//
//--------------------------------------------------------//
module parity_Check #(parameter WIDTH = 8, Prescale_Width = 5) (
    input wire clk,
    input wire rst_n,
    input wire par_chk_en,
    input wire PAR_TYP,
    input wire sampled_bit,
    input wire [WIDTH-1:0] P_DATA,
    input wire [Prescale_Width-1:0] edge_cnt,
    input wire [Prescale_Width-1:0] Prescale,
    output reg par_err
);

wire calc_parity; // PAR_TYP: 0 = even, 1 = odd
assign calc_parity = PAR_TYP ^ (^P_DATA);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        par_err <= 1'b0;
    end 
    else if (par_chk_en && (edge_cnt == Prescale - 1)) begin
        par_err <= (calc_parity != sampled_bit);
    end
end
endmodule
//--------------------------------------------------------//
//--------------------------------------------------------//
//--------------------------------------------------------//
module strt_Check #(parameter Prescale_Width = 5) (
    input wire clk,
    input wire rst_n,
    input wire strt_chk_en,
    input wire sampled_bit,
    input wire [Prescale_Width-1:0] edge_cnt,
    input wire [Prescale_Width-1:0] Prescale,
    output reg strt_glitch
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        strt_glitch <= 1'b0;
    end 
    else if (strt_chk_en && (edge_cnt == Prescale - 1)) begin
        strt_glitch <= (sampled_bit != 1'b0);   // start bit = 0
    end
end
endmodule
//--------------------------------------------------------//
//--------------------------------------------------------//
//--------------------------------------------------------//
module Stop_Check #(parameter Prescale_Width = 5) (
    input wire clk,
    input wire rst_n,
    input wire stp_chk_en,
    input wire sampled_bit,
    input wire [Prescale_Width-1:0] edge_cnt,
    input wire [Prescale_Width-1:0] Prescale,
    output reg stp_err
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        stp_err <= 1'b0;
    end 
    else if (stp_chk_en && (edge_cnt == Prescale - 1)) begin
        stp_err <= (sampled_bit != 1'b1); // stop bit = 1
    end
end
endmodule
//--------------------------------------------------------//
//--------------------------------------------------------//
//--------------------------------------------------------//
module UART_RX_FSM # (parameter
    bit_cnt_Width = 4,
    Prescale_Width = 5,
    idle   = 3'b000,
    start  = 3'b001,
    data   = 3'b010,
    parity = 3'b011,
    stop   = 3'b100,
    valid  = 3'b101
) (
    input wire clk,
    input wire rst_n, 
    input wire RX_IN,
    input wire PAR_EN,
    input wire [bit_cnt_Width-1:0] bit_cnt,
    input wire [Prescale_Width-1:0] edge_cnt,
    input wire [Prescale_Width-1:0] Prescale,
    input wire par_err,
    input wire strt_glitch,
    input wire stp_err,

    output reg dat_samp_en,
    output reg enable,
    output reg deser_en,
    output reg par_chk_en,
    output reg strt_chk_en,
    output reg stp_chk_en,
    output reg data_valid
);

reg [2:0] cs, ns;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cs <= idle;
    end else begin
        cs <= ns;
    end
end

always @(*) begin
    ns = cs; 
    case (cs)
        idle: begin
            if (!RX_IN) ns = start; // start bit = 0
        end
        start: begin
            if (bit_cnt == 1) begin
                if (strt_glitch) ns = idle;
                else             ns = data;
            end
        end
        data: begin
            if (bit_cnt == 9) begin
                if (PAR_EN) ns = parity;
                else        ns = stop;
            end
        end
        parity: begin
            if (bit_cnt == 10) begin
                ns = stop;
            end
        end
        stop: begin
            if (bit_cnt == (10 + PAR_EN)) begin
                ns = valid;
            end
        end
        valid: begin
            if (!RX_IN) ns = start; 
            else        ns = idle;
        end
        default: ns = idle;
    endcase
end

always @(*) begin
    dat_samp_en = 1'b0;
    enable      = 1'b0;
    deser_en    = 1'b0;
    par_chk_en  = 1'b0;
    strt_chk_en = 1'b0;
    stp_chk_en  = 1'b0;
    data_valid  = 1'b0;

    if (cs != idle && cs != valid) begin
        enable = 1'b1;
        dat_samp_en = 1'b1;
    end

    case (cs)
        start:  strt_chk_en = 1'b1;
        data:   deser_en    = 1'b1;
        parity: par_chk_en  = 1'b1;
        stop:   stp_chk_en  = 1'b1;
        valid: begin
            if (!par_err && !stp_err) data_valid = 1'b1;
        end
    endcase
end
endmodule
//--------------------------------------------------------//
//--------------------------------------------------------//
//--------------------------------------------------------//
module UART_RX #(
    parameter WIDTH = 8,
    parameter Prescale_Width = 5,
    parameter bit_cnt_Width = 4
) (
    input wire CLK,
    input wire RST_n,
    input wire RX_IN,
    input wire [Prescale_Width-1:0] Prescale,
    input wire PAR_EN,
    input wire PAR_TYP,

    output wire [WIDTH-1:0] P_DATA,
    output wire data_valid
);

wire sampled_bit;
wire dat_samp_en;
wire enable;
wire deser_en;
wire par_chk_en;
wire strt_chk_en;
wire stp_chk_en;
wire par_err;
wire strt_glitch;
wire stp_err;

wire [Prescale_Width-1:0] edge_cnt;
wire [bit_cnt_Width-1:0] bit_cnt;

data_sampling #(.Prescale_Width(Prescale_Width)) DS (
    .clk(CLK),
    .rst_n(RST_n),
    .RX_IN(RX_IN),
    .dat_samp_en(dat_samp_en),
    .edge_cnt(edge_cnt),
    .Prescale(Prescale),
    .sampled_bit(sampled_bit)
);

edge_bit_counter #(.Prescale_Width(Prescale_Width), .bit_cnt_Width(bit_cnt_Width)) counter (
    .clk(CLK),
    .rst_n(RST_n),
    .enable(enable),
    .Prescale(Prescale),
    .edge_cnt(edge_cnt),
    .bit_cnt(bit_cnt)
);

deserializer #(.WIDTH(WIDTH), .Prescale_Width(Prescale_Width)) SIPO (
    .clk(CLK),
    .rst_n(RST_n),
    .deser_en(deser_en),
    .sampled_bit(sampled_bit),
    .edge_cnt(edge_cnt),
    .Prescale(Prescale),
    .P_DATA(P_DATA)
);

parity_Check #(.WIDTH(WIDTH), .Prescale_Width(Prescale_Width)) par_check (
    .clk(CLK),
    .rst_n(RST_n),
    .par_chk_en(par_chk_en),
    .PAR_TYP(PAR_TYP),
    .sampled_bit(sampled_bit),
    .P_DATA(P_DATA),
    .edge_cnt(edge_cnt),
    .Prescale(Prescale),
    .par_err(par_err)
);

strt_Check #(.Prescale_Width(Prescale_Width)) start_check (
    .clk(CLK),
    .rst_n(RST_n),
    .strt_chk_en(strt_chk_en),
    .sampled_bit(sampled_bit),
    .edge_cnt(edge_cnt),
    .Prescale(Prescale),
    .strt_glitch(strt_glitch)
);

Stop_Check #(.Prescale_Width(Prescale_Width)) stop_sheck (
    .clk(CLK),
    .rst_n(RST_n),
    .stp_chk_en(stp_chk_en),
    .sampled_bit(sampled_bit),
    .edge_cnt(edge_cnt),
    .Prescale(Prescale),
    .stp_err(stp_err)
);

UART_RX_FSM #(.bit_cnt_Width(bit_cnt_Width), .Prescale_Width(Prescale_Width)) fsm (
    .clk(CLK),
    .rst_n(RST_n),
    .RX_IN(RX_IN),
    .PAR_EN(PAR_EN),
    .bit_cnt(bit_cnt),
    .edge_cnt(edge_cnt),
    .Prescale(Prescale),
    .par_err(par_err),
    .strt_glitch(strt_glitch),
    .stp_err(stp_err),
    .dat_samp_en(dat_samp_en),
    .enable(enable),
    .deser_en(deser_en),
    .par_chk_en(par_chk_en),
    .strt_chk_en(strt_chk_en),
    .stp_chk_en(stp_chk_en),
    .data_valid(data_valid)
);

endmodule