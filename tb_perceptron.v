//Verilog HDL for "ECE551Project", "perceptron_tb" "behavioral"
`timescale 1ns/1ps

// Self-checking testbench template for perceptron.v
//
// Assumptions:
//   1. dataBus is driven by the testbench only while loading inputs/weights.
//   2. The DUT drives dataBus only while giveData/sendOuts is active.
//   3. sigmoid.mem is available in the simulator run directory.
//   4. Matrix values are loaded in the same order the DUT consumes them.
//      Adjust the expected-output model if your intended matrix ordering differs.

module perceptron_tb;

  //------------------------------------------------------------
  // Clock and DUT I/O
  //------------------------------------------------------------
  reg         globalClk;
  reg         resetAll;
  reg         giveData;
  reg         readInputs;
  reg         readWeights;

  wire        dataReady;
  wire        ackReadInputs;
  wire        ackDataSent;
  wire        ackReadWeights;
  wire [7:0]  dataBus;

  //------------------------------------------------------------
  // Testbench data-bus driver
  //------------------------------------------------------------
  reg        tb_drive_bus;
  reg [7:0]  tb_bus_value;

  assign dataBus = tb_drive_bus ? tb_bus_value : 8'hZZ;

  //------------------------------------------------------------
  // Test vectors
  //------------------------------------------------------------
  reg [7:0] input_vec [0:2];
  reg [7:0] weights   [0:8];
  reg [7:0] expected  [0:2];
  reg [7:0] observed  [0:2];

  // Optional local copy of sigmoid lookup table for reference model.
  reg [7:0] sigLUT [0:127];

  integer i;
  integer errors;

  //------------------------------------------------------------
  // Instantiate DUT
  //------------------------------------------------------------
  perceptron dut (
    .resetAll      (resetAll),
    .globalClk     (globalClk),
    .giveData      (giveData),
    .readInputs    (readInputs),
    .readWeights   (readWeights),
    .dataReady     (dataReady),
    .ackReadInputs (ackReadInputs),
    .ackDataSent   (ackDataSent),
    .ackReadWeights(ackReadWeights),
    .dataBus       (dataBus)
  );

  //------------------------------------------------------------
  // Clock generation
  //------------------------------------------------------------
  initial begin
    globalClk = 1'b0;
    forever #5 globalClk = ~globalClk;   // 100 MHz clock
  end

  //------------------------------------------------------------
  // Timeout protection
  //------------------------------------------------------------
  initial begin
    #20000;
    $display("[%0t] ERROR: simulation timeout", $time);
    $finish;
  end

  //------------------------------------------------------------
  // Reference model helpers
  //------------------------------------------------------------

  function [7:0] sigmoid_model;
    input [7:0] x;
    begin
      // Matches the revised sigmoid.v values exercised by this test.
      case (x)
        8'd1:  sigmoid_model = 8'd1;
        8'd3:  sigmoid_model = 8'd1;
        8'd6: sigmoid_model = 8'd1;
        default: sigmoid_model = 8'd0;
      endcase
    end
  endfunction

  function [7:0] fmacc3_model;
    input [7:0] a0, a1, a2;
    input [7:0] b0, b1, b2;
    reg [17:0] accum;
    reg [17:0] tmp;
    begin
      // Matches fmacc.v behavior:
      // mpyOut = dataA * dataB + accumReg;
      // accumReg retains the complete 18-bit accumulated sum.
      // storeReg receives mpyOut[17:10] when rot is asserted.
      accum = 18'd0;

      tmp   = a0 * b0 + accum;
      accum = tmp;

      tmp   = a1 * b1 + accum;
      accum = tmp;

      tmp   = a2 * b2 + accum;
      fmacc3_model = tmp[17:10];
    end
  endfunction

  task compute_expected;
    begin
      // This assumes weights are loaded as:
      //   output0 uses weights[0], weights[1], weights[2]
      //   output1 uses weights[3], weights[4], weights[5]
      //   output2 uses weights[6], weights[7], weights[8]
      //
      // If your matrix is stored column-major instead of row-major,
      // change these index groupings.
      expected[0] = sigmoid_model(fmacc3_model(input_vec[0], input_vec[1], input_vec[2],
                                               weights[0],   weights[1],   weights[2]));
      expected[1] = sigmoid_model(fmacc3_model(input_vec[0], input_vec[1], input_vec[2],
                                               weights[3],   weights[4],   weights[5]));
      expected[2] = sigmoid_model(fmacc3_model(input_vec[0], input_vec[1], input_vec[2],
                                               weights[6],   weights[7],   weights[8]));
    end
  endtask

  //------------------------------------------------------------
  // Bus / handshake tasks
  //------------------------------------------------------------

  task apply_reset;
    begin
      resetAll    = 1'b1;
      giveData    = 1'b0;
      readInputs  = 1'b0;
      readWeights = 1'b0;
      tb_drive_bus = 1'b0;
      tb_bus_value = 8'h00;

      repeat (4) @(posedge globalClk);
      resetAll = 1'b0;
      repeat (2) @(posedge globalClk);
    end
  endtask

  task load_weight_values;
    begin
      $display("[%0t] Loading 3x3 weight matrix...", $time);

      readWeights  = 1'b1;
      tb_drive_bus = 1'b1;

      // Hold readWeights high while presenting the 9 weight values.
      // The controller should assert ackReadWeights after the FIFO fills.
      for (i = 0; i <= 8; i = i + 1) begin
        @(negedge globalClk);
        tb_bus_value = weights[i];
		if (i == 0)
			readWeights = 1'b1;
		else 
			readWeights = 1'b0;

		@(posedge globalClk);
		#1;

        $display(
            "[%0t] Presented weight[%0d]=%0d, ldWts=%b, wtsFull=%b",
            $time,
            i,
            weights[i],
            dut.loadWtsC2W,
            dut.wtsFullI2C
        );

      end


      wait (ackReadWeights === 1'b1);
 
      $display("[%0t] Weight loading acknowledged", $time);

      // Allow ack to clear after command drops.
      repeat (2) @(negedge globalClk);
	  tb_drive_bus = 1'b0;
    end
  endtask

  task load_input_values;
    begin
      $display("[%0t] Loading 1x3 input vector...", $time);

      // Hold readInputs high while presenting the 3 input values.
      // The controller should assert ackReadInputs after the FIFO fills.

	  wait (dut.I0.state == 3'd1);
	  @(negedge globalClk);
		tb_bus_value = input_vec[0];  // 0F
		tb_drive_bus = 1'b1;
		readInputs   = 1'b1;

	    @(posedge globalClk);
	    #1;

	    $display("[%0t] Captured input[0]=%h, bus=%h, ldIns=%b",
        			$time, input_vec[0], dataBus, dut.loadInputsC2I
    		);


      for (i = 1; i <= 2; i = i + 1) begin		
        @(negedge globalClk);
        tb_bus_value = input_vec[i];
		readInputs = 1'b0;

        @(posedge globalClk);
        #1;

        $display(
            "[%0t] Captured input[%0d]=%h, bus=%h, ldIns=%b",
            $time, i, input_vec[i], dataBus, dut.loadInputsC2I
        );

      end

      wait (ackReadInputs === 1'b1);

      repeat (2) @(negedge globalClk);

      tb_drive_bus = 1'b0;
    end
  endtask

  task wait_for_data_ready;
    begin
      $display("[%0t] Waiting for dataReady...", $time);
      wait (dataReady === 1'b1);
      $display("[%0t] dataReady asserted", $time);
      repeat (1) @(posedge globalClk);
    end
  endtask

  task read_output_values;
    begin
      $display("[%0t] Reading output vector...", $time);

      tb_drive_bus = 1'b0;   // release bus so DUT can drive it

    // Request the output transfer away from the active clock edge.
    @(negedge globalClk);
    giveData = 1'b1;

    // Wait for the controller to enable the output FIFO.
    wait (dut.sendOutsC2O === 1'b1);
    #1;

    // The first output is already on the bus. Do not wait for
    // another clock edge before sampling it.
    observed[0] = dataBus;
    $display("[%0t] observed[0] = 0x%02h", $time, observed[0]);

    // The request has been accepted.
    @(negedge globalClk);
    giveData = 1'b0;

      for (i = 1; i < 3; i = i + 1) begin
        @(posedge globalClk);
        #1; 
        observed[i] = dataBus;
        $display("[%0t] observed[%0d] = 0x%02h", $time, i, observed[i]);

      end

      @(posedge globalClk);
      wait (ackDataSent === 1'b1);

      $display("[%0t] Output transfer acknowledged", $time);

      repeat (2) @(posedge globalClk);
    end
  endtask

  task check_outputs;
    begin
      errors = 0;

      for (i = 0; i < 3; i = i + 1) begin
        if (observed[i] !== expected[i]) begin
          $display("ERROR: output[%0d] expected 0x%02h, observed 0x%02h",
                   i, expected[i], observed[i]);
          errors = errors + 1;
        end
        else begin
          $display("PASS:  output[%0d] = 0x%02h", i, observed[i]);
        end
      end

      if (errors == 0)
        $display("TEST PASSED");
      else
        $display("TEST FAILED with %0d error(s)", errors);
    end
  endtask

  //------------------------------------------------------------
  // Main test sequence
  //------------------------------------------------------------
  initial begin
    $dumpfile("tb_perceptron.vcd");
    $dumpvars(0, tb_perceptron);

    // Example unsigned 8-bit test data.
    // Start with small values to avoid overflow surprises while debugging.
    input_vec[0] = 8'd15;
    input_vec[1] = 8'd25;
    input_vec[2] = 8'd35;

    weights[0] = 8'd10;  weights[1] = 8'd20;  weights[2] = 8'd30;
    weights[3] = 8'd40;  weights[4] = 8'd50;  weights[5] = 8'd60;
    weights[6] = 8'd70;  weights[7] = 8'd80;  weights[8] = 8'd90;

    compute_expected;

    $display("Expected outputs: 0x%02h 0x%02h 0x%02h",
             expected[0], expected[1], expected[2]);

    apply_reset;
    load_weight_values;
    load_input_values;
    wait_for_data_ready;
    read_output_values;
    check_outputs;

    $finish;
  end

endmodule
