module UART_RX_tb();
    parameter WIDTH = 8;
    parameter Prescale_Width = 5;
    parameter bit_cnt_Width = 4;

    reg CLK;
    reg RST_n;
    reg RX_IN;
    reg [Prescale_Width-1:0] Prescale;
    reg PAR_TYP;
    reg PAR_EN;
    
    wire [WIDTH-1:0] P_DATA;
    wire data_valid;

UART_RX #(
    .WIDTH(WIDTH),
    .Prescale_Width(Prescale_Width),
    .bit_cnt_Width(bit_cnt_Width)
) DUT (
    .CLK(CLK),
    .RST_n(RST_n),
    .RX_IN(RX_IN),
    .Prescale(Prescale),
    .PAR_EN(PAR_EN),
    .PAR_TYP(PAR_TYP),
    .P_DATA(P_DATA),
    .data_valid(data_valid)
);

always #2.5 CLK = ~CLK;

initial begin
        CLK = 1'b0;
        RST_n = 1'b1;
        RX_IN = 1'b1;        // IDLE
        Prescale = 5'd8;     // oversampling to 8
        PAR_EN = 1'b0;
        PAR_TYP = 1'b0;

        reset();
        
        send_frame({1'b1, 8'hA5, 1'b0}, 10, 1'b0, 1'b0); //No Parity

        send_frame({1'b1, 1'b0, 8'hF3, 1'b0}, 11, 1'b1, 1'b0); // partiy & even

        send_frame({1'b1, 1'b1, 8'h3C, 1'b0}, 11, 1'b1, 1'b1); // partiy & odd
        #20;
        $finish; 
end

initial begin
    $monitor("Time = %0t ns | RST_n = %b | RX_IN = %b | P_DATA = %h | data_valid = %b | PAR_EN = %b | PAR_TYP = %b",
             $time, RST_n, RX_IN, P_DATA, data_valid, PAR_EN, PAR_TYP);
end
    
initial begin
  $dumpfile("dump.vcd");
  $dumpvars(1);
end
    
task reset();
    begin
        RST_n = 1'b1;
        #10;
        RST_n = 1'b0; 
        #10;
        RST_n = 1'b1;
        #20;
    end
endtask

task send_frame (input [10:0] frame, input [3:0] frame_len, input p_en, input p_typ); 
    integer i;
    begin
        PAR_EN = p_en;
        PAR_TYP = p_typ;

        for (i = 0; i < frame_len; i = i + 1) begin
            RX_IN = frame[i];
            repeat(8) @(posedge CLK);
        end
        
        @(posedge data_valid);
        #40;
    end
endtask
endmodule
