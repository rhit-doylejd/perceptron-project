//Verilog HDL for "ECE551Project", "weightFIFO" "behavioral"


module weightFIFO (input clk, input load, input rot, input rst, input [7:0] fifoDataIn, output fifoFull, output [7:0] fifoDataOut );

integer i;
reg [8:0] fifoReg [0:8];

assign fifoFull = fifoReg[0][8];
assign fifoDataOut = fifoReg[0][7:0];

always @(posedge clk) begin
	if (rst) begin
		for (i=0;i<9; i=i+1) begin
			fifoReg[i] <= 9'd0;
		end
	end

	if (load) begin
		fifoReg[8][7:0] <= fifoDataIn;
		fifoReg[8][8] <= 1;
		for(i=0;i<=7;i=i+1)begin
			fifoReg[i] <= fifoReg[i+1];
		end
	end

	else if (rot) begin
		fifoReg[8] <= fifoReg[0];
		for (i=0;i<=7;i=i+1) begin
			fifoReg[i] <= fifoReg[i+1];
		end
	end

end
endmodule
