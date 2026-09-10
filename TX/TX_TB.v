module UART_TX_tb();
    reg clk;
    reg rst;
    reg PAR_TYP;
    reg PAR_EN;
    reg [7:0] P_Data;
    reg Data_Valid;
    
    wire TX_OUT;
    wire busy;

TX_Wrapper #( .WIDTH(8) ) DUT (
    .clk(clk),
    .rst(rst),
    .PAR_TYP(PAR_TYP),
    .PAR_EN(PAR_EN),
    .P_Data(P_Data),
    .Data_Valid(Data_Valid),
    .TX_OUT(TX_OUT),
    .busy(busy)
);

always  #2.5 clk = ~clk;

initial begin
    clk = 1'b0;
    rst = 1'b1;
    Data_Valid = 1'b0;
    PAR_EN = 1'b0;
    PAR_TYP = 1'b0;
    P_Data = 'h00;

    reset();
    
    send('hA5, 1'b0, 1'b0); // no partiy
    send('hF3, 1'b1, 1'b0); // partiy & even
    send('h3C, 1'b1, 1'b1); // partiy & odd
    #40;
    $finish; 
end

initial begin
    $monitor("Time = %0t ns | rst = %b | Data_Valid = %b | P_Data = %h | PAR_EN = %b | PAR_TYP = %b | busy = %b | TX_OUT = %b",
             $time, rst, Data_Valid, P_Data, PAR_EN, PAR_TYP, busy, TX_OUT);
end

initial begin
  $dumpfile("dump.vcd");
  $dumpvars(1);
end
    
task reset();
    begin
        rst = 1'b1;
        #10;
        rst = 1'b0; 
        #10;
        rst = 1'b1;
        #20;
    end
endtask

task send (input [7:0] data_in, input p_en, input p_typ); 
    begin
        @(posedge clk);
        P_Data = data_in;
        PAR_EN = p_en;
        PAR_TYP = p_typ;
        Data_Valid = 1'b1;  
        
        @(posedge clk);
        Data_Valid = 1'b0;
        @(negedge busy);
        #20;
    end
endtask
endmodule
