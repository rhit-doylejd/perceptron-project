//Verilog HDL for "ECE551Project", "fmacc" "behavioral"


module fmacc (input clk, input rst, input rot, input stall, input [7:0] dataA, input [7:0] dataB, output colDone, output [7:0] fmacOut);

	reg [17:0] accumReg;
	reg [8:0] storeReg;
	wire [17:0] mpyOut;

assign mpyOut = {1'b0, dataA} * {1'b0, dataB} + accumReg;
assign fmacOut = storeReg[7:0];
assign colDone = storeReg[8];

always @(posedge clk) begin

    if (rst) begin
        storeReg <= 9'd0;
        accumReg <= 18'd0;
    end

    else if (!stall) begin

        if (rot) begin
            storeReg[7:0] <= mpyOut[17:10];
            storeReg[8] <= 1'b1;
            accumReg <= 18'd0;
        end

        else begin
            accumReg <= mpyOut;
        end

    end

end


endmodule
