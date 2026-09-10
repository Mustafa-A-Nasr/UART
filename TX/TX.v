module serializer #(parameter WIDTH = 8) (
    input wire [WIDTH-1:0] P_Data,
    input wire Ser_En,
    input wire Clk,
    input wire Reset_Ser,   
    output reg Ser_Done,
    output wire Ser_Data 
);

reg [WIDTH-1:0] shift_reg;
reg [3:0] counter;
assign Ser_Data = shift_reg[0]; 

always @(posedge Clk or negedge Reset_Ser) begin
    if (!Reset_Ser) begin
        shift_reg <= 0;
        Ser_Done <= 0;
        counter <= 0;
    end 
    else if (Ser_En) begin
        shift_reg <= P_Data; 
        Ser_Done <= 0;
        counter <= 0;
    end 
    else if (!Ser_Done) begin
        shift_reg <= shift_reg >> 1;
        if (counter == WIDTH - 1) begin
            Ser_Done <= 1'b1;
        end else begin
            counter <= counter + 1;
        end
    end
end
endmodule
//--------------------------------------------------------//
//--------------------------------------------------------//
//--------------------------------------------------------//
module Parity_Calc #(parameter  WIDTH = 8) (
    input wire [WIDTH-1:0] P_Data,
    input wire Data_Valid,
    input wire PAR_TYP,

    output reg Par_bit
);

reg XOR_Out;

always @(*) begin
    XOR_Out = ^ P_Data; // PAR_TYP: 0 = even, 1 = odd
    Par_bit = (PAR_TYP ^ XOR_Out); 
end
endmodule
//--------------------------------------------------------//
//--------------------------------------------------------//
//--------------------------------------------------------//
module FSM # (parameter
    idle = 3'b000,
    start = 3'b001,
    data = 3'b010,
    parity = 3'b011,
    stop = 3'b100
) (
    input wire clk,
    input wire rst, 
    input wire Data_Valid,
    input wire Ser_Done,
    input wire PAR_EN,

    output reg [1:0] mux_sel,
    output reg busy,
    output reg Ser_En
);

reg [2:0] cs, ns;

always @(posedge clk or negedge rst) begin
    if (!rst) begin
        cs <= idle;
    end else begin
        cs <= ns;
    end
end

always @(*) begin
    ns = cs; 
    case (cs)
        idle: begin
            if (Data_Valid) ns = start;
        end
        start: begin
            ns = data;
        end
        data: begin
            if (Ser_Done) begin
                if (PAR_EN) ns = parity ;
                else        ns = stop;
            end
        end
        parity : begin
            ns = stop;
        end
        stop: begin
            ns = idle;
        end
        default: ns = idle;
    endcase
end

always @(*) begin
    busy = 1'b1;
    Ser_En = 1'b0;
    mux_sel = 2'b00;
    if (cs == idle) begin
        busy = 1'b0;
        mux_sel = 2'b00; 
    end
    else if (cs == start) begin
        Ser_En = 1'b1;
        mux_sel = 2'b01;
    end 
    else if (cs == data) begin
        mux_sel = 2'b10;
    end 
    else if (cs == parity) begin
        mux_sel = 2'b11;
    end 
    else if (cs == stop) begin
        mux_sel = 2'b00;
    end
end
endmodule
//--------------------------------------------------------//
//--------------------------------------------------------//
//--------------------------------------------------------//
module MUX #(parameter start_bit = 1'b0, Stop_bit= 1'b1 ) (
    input wire [1:0] mux_sel,
    input wire Ser_Data,
    input wire Par_bit,
    output reg TX_OUT
);

always @(*) begin
    case (mux_sel)
        2'b00: TX_OUT = Stop_bit; 
        2'b01: TX_OUT = start_bit; 
        2'b10: TX_OUT = Ser_Data; 
        2'b11: TX_OUT = Par_bit; 
        default: TX_OUT = 1'b1; // idle
    endcase
end
endmodule
//--------------------------------------------------------//
//--------------------------------------------------------//
//--------------------------------------------------------//
module TX_Wrapper #(parameter WIDTH = 8) (
    input wire clk,
    input wire rst,
    input wire PAR_TYP,
    input wire PAR_EN,
    input wire [WIDTH-1:0] P_Data,
    input wire Data_Valid,

    output wire TX_OUT, 
    output wire busy
);

wire Ser_Done, Ser_En, Ser_Data, Par_bit; 
wire [1:0] mux_sel;

serializer SIPO (
    .Clk(clk),
    .P_Data(P_Data),
    .Ser_En(Ser_En),
    .Reset_Ser(rst),
    .Ser_Done(Ser_Done),
    .Ser_Data(Ser_Data)
    );
    
    Parity_Calc PC (
    .P_Data(P_Data),
    .Data_Valid(Data_Valid),
    .PAR_TYP(PAR_TYP),
    .Par_bit(Par_bit)
    );

    FSM fsm (
    .Data_Valid(Data_Valid),
    .Ser_Done(Ser_Done),
    .PAR_EN(PAR_EN),
    .rst(rst),
    .clk(clk),
    .mux_sel(mux_sel),
    .busy(busy),
    .Ser_En(Ser_En)
    );

    MUX mux (
    .mux_sel(mux_sel),
    .Ser_Data(Ser_Data),
    .Par_bit(Par_bit),
    .TX_OUT(TX_OUT)
    );
endmodule