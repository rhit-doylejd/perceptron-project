//Verilog HDL for "ECE551Project", "outputFIFO" "behavioral"


module outputFIFO (input clk, input rst, input load, input rotOut, input [7:0] fifoDataIn, output [2:0] fifoStat, output [7:0] fifoDataOut );

reg [8:0] fifoReg [0:2];

assign fifoDataOut = rotOut ? fifoReg[2][7:0] : {8{1'bz}};
assign fifoStat = {fifoReg[0][8] , fifoReg[1][8], fifoReg[2][8]};



always @(posedge clk) begin
	if (rst) begin
		fifoReg[0] <= 9'd0;
		fifoReg[1] <= 9'd0;
		fifoReg[2] <= 9'd0;
	end

	else if ( load ) begin
		fifoReg[0][7:0] <= fifoDataIn;
		fifoReg[0][8] <= 1'b1;
		fifoReg[1] <= fifoReg[0];
		fifoReg[2] <= fifoReg[1];
	end

	else if (rotOut) begin
		fifoReg[0][7:0] <= fifoReg[2][7:0];
		fifoReg[0][8] <= 1'b0; 
		fifoReg[1] <= fifoReg[0];
		fifoReg[2] <= fifoReg[1];
	end	

end

endmodule
