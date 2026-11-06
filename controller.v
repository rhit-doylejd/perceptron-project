//Verilog HDL for "ECE551Project", "controller" "behavioral"


module controller (

    input  wire clk,
    input  wire rstAll,
    input  wire readWts,
    input  wire readIns,
    input  wire giveData,
    input  wire insFull,
    input  wire wtsFull,
    input  wire insCycled,
	input  wire colDone,
    input  wire [2:0] outStatus,
	input  wire busAck,
	output reg  busReq,
	output reg  popOut,
 	output reg  ackRdWts,
    output reg  ackRdIns,
    output reg  ackDataSent,
	output reg  dataReady,
    output reg  rotWts,
    output reg  rotIns,
    output reg  rotMpy,
    output reg  rstWts,
	output reg  rstIns,
    output reg  rstOuts,
	output reg  rstMpy,
    output reg  sendOuts,
    output reg  ldWts,
    output reg  ldIns,
    output reg  ldOuts
);

    //---------------------------------------------------------
    // State encoding
    //---------------------------------------------------------
    localparam INIT = 3'd0,
           IDLE = 3'd1,
           LDWTS = 3'd2,
           LDINS = 3'd3,
           DOMPY = 3'd4,
           SENDDATA = 3'd5,
           WAIT_ACK_LOW = 3'd6;
	

    reg [2:0] state, next_state;

always @(posedge clk) begin
    if (rstAll)
        state <= INIT;
    else
        state <= next_state;
end

always @(posedge clk) begin

	if (rstAll) begin
		ackRdWts <= 1'b0;
		ackRdIns <=1'b0;
		ackDataSent <= 1'b0;
		dataReady <=1'b0;
	end

	if (state == IDLE && readWts)
		ackRdWts <= 1'b0;
	else if (state == LDWTS && wtsFull)
		ackRdWts <= 1'b1;

	if (state == IDLE && readIns)
		ackRdIns <= 1'b0;
	else if (state == LDINS && insFull)
		ackRdIns <= 1'b1;

	if (state == IDLE && giveData)
		ackDataSent <= 1'b0;
	else if (state == SENDDATA && outStatus == 3'b000)
		ackDataSent <=1'b1;

	if (state == SENDDATA && outStatus == 3'b000)
		dataReady <= 1'b0;
	else if (state == DOMPY && outStatus == 3'b111)
		dataReady <= 1'b1; 

end
		

always @(*) begin

    // Defaults
    next_state = state;
	busReq = 1'b0;
	popOut = 1'b0;
    rotWts=0;
    rotIns=0;
    rotMpy=0;
    rstWts=0;
	rstIns=0;
    rstOuts=0;
	rstMpy=0;
	sendOuts=0;
    ldWts=0;
    ldIns=0;
    ldOuts=0;


    case(state)

        INIT:begin
		    rstIns = 1;
		    rstOuts = 1;
		    rstMpy = 1;
		    rstWts = 1;

            if (~rstAll)
                next_state = IDLE;
		end

        IDLE:begin

            if (rstAll)
                next_state = INIT;
		    else if (readWts) begin
				ldWts = 1'b1;
				next_state = LDWTS;
			end
			else if (readIns) begin
				ldIns = 1'b1;
				next_state = LDINS;
			end
			else if (insFull && wtsFull && (outStatus == 3'b000)) begin
				rstMpy = 1'b1;
				next_state = DOMPY;
			end
			else if (giveData) begin
				next_state = SENDDATA;
			end
		end

        LDWTS: begin
			ldWts = 1'b1;			
            	if (wtsFull) begin
				ldWts = 1'b0;
     	       	next_state = IDLE;
			end
        end

        LDINS: begin
            ldIns = 1'b1;
            if (insFull) begin
				ldIns = 1'b0;
                next_state = IDLE;
			end
        end

        DOMPY: begin
            rotIns = 1'b1;
            rotWts = 1'b1;

			if (insCycled)
				rotMpy = 1'b1;

			if (insCycled && colDone)
				ldOuts = 1'b1;

			if (outStatus == 3'b111) begin
				rotMpy = 1'b0;
				ldOuts = 1'b0;
				rotWts = 1'b0;
				rotIns = 1'b0;
				next_state = IDLE;
			end
		end

        SENDDATA: begin
            if (outStatus == 3'b000) begin
        		next_state = IDLE;
			end
			else begin
        		sendOuts = 1'b1;
        		busReq = 1'b1;

				if (busAck) begin
           		 	popOut = 1'b1;
            		next_state = WAIT_ACK_LOW;
				end
        	end
		end 
	WAIT_ACK_LOW: begin

    	if (!busAck) begin

        	if (outStatus == 3'b000)
            	next_state = IDLE;
        	else
            	next_state = SENDDATA;
		end

	end

    endcase
end
endmodule
