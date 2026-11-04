//Verilog HDL for "ECE551Project", "inputFIFO" "behavioral"


module inputFIFO (input clk, input rot, input load, input rst, input [7:0] fifoDataIn, output fifoFull, output fifoCycled, output [7:0] fifoDataOut );

reg [9:0] fifoReg [0:2];

assign fifoDataOut = fifoReg[0][7:0]; 
assign fifoCycled = ~fifoReg[0][9] & fifoReg[1][9] & fifoReg[2][9];
assign fifoFull = fifoReg[0][8] & fifoReg[1][8] & fifoReg[2][8];


always @(posedge clk) begin
	if (rst) begin
		fifoReg[0] <= 10'd0;
		fifoReg[1] <= 10'd0;
		fifoReg[2] <= 10'd0;
	end

	else if (rot) begin
		fifoReg[0] <= fifoReg[1];
		fifoReg[1] <= fifoReg[2];
		fifoReg[2] <= fifoReg[0][7:0];
		if ( fifoCycled ) begin
			fifoReg[0][9] <= 1'b0;
			fifoReg[1][9] <= 1'b0;
			fifoReg[2][9] <= 1'b0;
		end
		else  
			fifoReg[2][9] <= 1'b1;
	end

	else if (load) begin
		fifoReg[0] <= fifoReg[1];
		fifoReg[1] <= fifoReg[2];
		fifoReg[2][7:0] <= fifoDataIn;
		fifoReg[2][9:8] <= 2'b01;
	end


end
endmodule
