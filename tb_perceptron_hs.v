`timescale 1ns/1ps
// Self-checking system testbench for the 4-phase busReq/busAck output handshake redesign
//
// RTL sim (from sim/):
//   xrun -access +rwc ../tb_perceptron_hs.v ../perceptron.v ../controller.v ../inputFIFO.v
//        ../weightFIFO.v ../fmacc.v ../sigmoid.v ../outputFIFO.v
//
// Gate-level sim with SDF (from sim/): add +define+GATE, and swap the RTL files for the
// synthesized netlist plus the GPDK045 cell models:
//   xrun -access +rwc -timescale 1ns/1ps +define+GATE ../tb_perceptron_hs.v
//        ../outputs/perceptron_syn.v <path>/slow_vdd1v0_basicCells.v
//   Override the SDF location with +define+SDF_FILE=\"path/to/file.sdf\" if needed.
//
// In GATE mode the testbench only probes nets that survive synthesis
// (sendOutsC2O, net6). The controller's internal state register is renamed by
// Genus, so state-based checks are compiled out.
module tb_perceptron_hs;

  reg         globalClk, resetAll, giveData, readInputs, readWeights, busAck;
  wire        dataReady, ackReadInputs, ackDataSent, ackReadWeights, busReq;
  wire [7:0]  dataBus;

  reg        tb_drive_bus;
  reg [7:0]  tb_bus_value;
  assign dataBus = tb_drive_bus ? tb_bus_value : 8'hZZ;

  reg [7:0] input_vec [0:2];
  reg [7:0] weights   [0:8];
  reg [7:0] expected  [0:2];
  reg [7:0] observed  [0:2];

  integer i, errors, total_errors, send_cycles, seed;

  // Reference sigmoid: a second copy of the real LUT
  reg  [7:0] refSigIn;
  wire [7:0] refSigOut;
  sigmoid refSig (.dataIn(refSigIn), .dataOut(refSigOut));

  perceptron dut (
    .resetAll(resetAll), .globalClk(globalClk), .giveData(giveData),
    .readInputs(readInputs), .readWeights(readWeights), .busAck(busAck),
    .dataReady(dataReady), .ackReadInputs(ackReadInputs), .ackDataSent(ackDataSent),
    .ackReadWeights(ackReadWeights), .busReq(busReq), .dataBus(dataBus)
  );

`ifdef GATE
  // Back-annotate post-synthesis cell and net delays onto the DUT
  `ifndef SDF_FILE
    `define SDF_FILE "../outputs/perceptron_syn.sdf"
  `endif
  initial $sdf_annotate(`SDF_FILE, dut);
`endif

  initial begin globalClk = 1'b0; forever #5 globalClk = ~globalClk; end
  initial begin #200000; $display("[%0t] ERROR: simulation timeout", $time); $finish; end

  // Bus contention monitor
  always @(posedge globalClk)
    if (tb_drive_bus && dut.sendOutsC2O) begin
      $display("[%0t] ERROR: bus contention (TB and DUT both driving)", $time);
      total_errors = total_errors + 1;
    end

  //------------------------------------------------------------ models
  function [7:0] fmacc3_model;
    input [7:0] a0, a1, a2, b0, b1, b2;
    reg [17:0] accum;
    begin
      accum = 18'd0;
      accum = a0 * b0 + accum;
      accum = a1 * b1 + accum;
      accum = a2 * b2 + accum;
      fmacc3_model = accum[17:10];
    end
  endfunction

  task compute_expected;
    integer r;
    begin
      for (r = 0; r < 3; r = r + 1) begin
        refSigIn = fmacc3_model(input_vec[0], input_vec[1], input_vec[2],
                                weights[3*r], weights[3*r+1], weights[3*r+2]);
`ifdef GATE
        // refSig is the gate-level sigmoid in GATE mode; give it time to settle
        #20 expected[r] = refSigOut;
`else
        #1 expected[r] = refSigOut;
`endif
      end
      $display("Expected outputs: 0x%02h 0x%02h 0x%02h", expected[0], expected[1], expected[2]);
    end
  endtask

  task set_vectors;
    input integer sel;
    begin
      case (sel)
        0: begin                     // from tb_perceptron.v (all outputs 0x01)
          input_vec[0]=8'd15; input_vec[1]=8'd25; input_vec[2]=8'd35;
          weights[0]=8'd10; weights[1]=8'd20; weights[2]=8'd30;
          weights[3]=8'd40; weights[4]=8'd50; weights[5]=8'd60;
          weights[6]=8'd70; weights[7]=8'd80; weights[8]=8'd90;
        end
        1: begin                     // from tb_perceptron_2.v (distinct outputs)
          input_vec[0]=8'd255; input_vec[1]=8'd255; input_vec[2]=8'd255;
          weights[0]=8'd40;  weights[1]=8'd40;  weights[2]=8'd40;
          weights[3]=8'd128; weights[4]=8'd128; weights[5]=8'd128;
          weights[6]=8'd216; weights[7]=8'd216; weights[8]=8'd216;
        end
        2: begin                     // mixed magnitudes, distinct per-row sums
          input_vec[0]=8'd100; input_vec[1]=8'd200; input_vec[2]=8'd50;
          weights[0]=8'd255; weights[1]=8'd128; weights[2]=8'd64;
          weights[3]=8'd32;  weights[4]=8'd16;  weights[5]=8'd8;
          weights[6]=8'd250; weights[7]=8'd240; weights[8]=8'd230;
        end
        3: begin                     // zero inputs: every output = sigmoid(0)
          input_vec[0]=8'd0; input_vec[1]=8'd0; input_vec[2]=8'd0;
          weights[0]=8'd17;  weights[1]=8'd99;  weights[2]=8'd201;
          weights[3]=8'd63;  weights[4]=8'd150; weights[5]=8'd7;
          weights[6]=8'd222; weights[7]=8'd45;  weights[8]=8'd180;
        end
        4: begin                     // alternating bit patterns: high bus/register toggling
          input_vec[0]=8'hAA; input_vec[1]=8'h55; input_vec[2]=8'hF0;
          weights[0]=8'h0F; weights[1]=8'hF0; weights[2]=8'hAA;
          weights[3]=8'h55; weights[4]=8'hFF; weights[5]=8'h01;
          weights[6]=8'h80; weights[7]=8'h7F; weights[8]=8'hC3;
        end
        default: begin               // 5: full scale, largest possible sum (190)
          input_vec[0]=8'd255; input_vec[1]=8'd255; input_vec[2]=8'd255;
          weights[0]=8'd255; weights[1]=8'd255; weights[2]=8'd255;
          weights[3]=8'd255; weights[4]=8'd255; weights[5]=8'd255;
          weights[6]=8'd255; weights[7]=8'd255; weights[8]=8'd255;
        end
      endcase
    end
  endtask

  //------------------------------------------------------------ bus tasks
  task apply_reset;
    begin
      resetAll = 1'b1; giveData = 1'b0; readInputs = 1'b0; readWeights = 1'b0;
      busAck = 1'b0; tb_drive_bus = 1'b0; tb_bus_value = 8'h00;
      repeat (4) @(posedge globalClk);
      resetAll = 1'b0;
      repeat (2) @(posedge globalClk);
    end
  endtask

  task load_weight_values;     // same sequence as the original TB
    begin
      readWeights = 1'b1; tb_drive_bus = 1'b1;
      for (i = 0; i <= 8; i = i + 1) begin
        @(negedge globalClk);
        tb_bus_value = weights[i];
        readWeights  = (i == 0);
        @(posedge globalClk); #1;
      end
      wait (ackReadWeights === 1'b1);
      repeat (2) @(negedge globalClk);
      tb_drive_bus = 1'b0;
    end
  endtask

  task load_input_values;      // same sequence as the original TB
    begin
`ifndef GATE
      wait (dut.I0.state == 3'd1);   // controller back in IDLE (RTL-only probe)
`endif
      @(negedge globalClk);
      tb_bus_value = input_vec[0]; tb_drive_bus = 1'b1; readInputs = 1'b1;
      @(posedge globalClk); #1;
      for (i = 1; i <= 2; i = i + 1) begin
        @(negedge globalClk);
        tb_bus_value = input_vec[i]; readInputs = 1'b0;
        @(posedge globalClk); #1;
      end
      wait (ackReadInputs === 1'b1);
      repeat (2) @(negedge globalClk);
      tb_drive_bus = 1'b0;
    end
  endtask

  task wait_for_data_ready;
    begin
      wait (dataReady === 1'b1);
      @(posedge globalClk);
    end
  endtask

  // mode 0 = ack immediately, 1 = wait nstall cycles before ack, 2 = random 0-7
  task read_outputs_hs;
    input integer mode;
    input integer nstall;
    integer n, s, cyc;
    reg [7:0] held;
    begin
      tb_drive_bus = 1'b0; busAck = 1'b0; n = 0; cyc = 0;
      @(negedge globalClk) giveData = 1'b1;
      wait (busReq === 1'b1);
      @(negedge globalClk) giveData = 1'b0;

      while (n < 3) begin
        while (busReq !== 1'b1) begin @(negedge globalClk); cyc = cyc + 1; end

        s    = (mode == 1) ? nstall : (mode == 2) ? ($random(seed) & 7) : 0;
        held = dataBus;
        repeat (s) begin                       // receiver is "busy": DUT must hold
          @(negedge globalClk); cyc = cyc + 1;
          if (busReq !== 1'b1 || dataBus !== held) begin
            $display("[%0t] ERROR: req dropped or bus changed during stall", $time);
            errors = errors + 1;
          end
        end

        observed[n] = dataBus;
        $display("[%0t] observed[%0d] = 0x%02h (after %0d stall cycles)", $time, n, dataBus, s);
        n = n + 1;
        busAck = 1'b1;                          // phase 2: ack high
        @(negedge globalClk); cyc = cyc + 1;
        while (busReq === 1'b1) begin @(negedge globalClk); cyc = cyc + 1; end
        busAck = 1'b0;                          // phase 4: ack low
        @(negedge globalClk); cyc = cyc + 1;
      end

      wait (ackDataSent === 1'b1);
      send_cycles = cyc;
      $display("[%0t] Output transfer acknowledged, send took %0d cycles", $time, send_cycles);
      repeat (2) @(negedge globalClk);
    end
  endtask

  task check_outputs;
    input [8*24-1:0] name;
    begin
      for (i = 0; i < 3; i = i + 1)
        if (observed[i] !== expected[i]) begin
          $display("ERROR: %0s output[%0d] expected 0x%02h, observed 0x%02h", name, i, expected[i], observed[i]);
          errors = errors + 1;
        end
      if (errors == 0) $display("PASS: %0s", name);
      else             $display("FAIL: %0s (%0d errors)", name, errors);
      total_errors = total_errors + errors;
      errors = 0;
    end
  endtask

  task full_transaction;
    input integer sel, mode, nstall;
    input [8*24-1:0] name;
    begin
      set_vectors(sel); compute_expected;
      apply_reset; load_weight_values; load_input_values; wait_for_data_ready;
      read_outputs_hs(mode, nstall);
      check_outputs(name);
    end
  endtask

  //------------------------------------------------------------ main
  initial begin
`ifdef GATE
    $dumpfile("tb_perceptron_hs_gate.vcd");
`else
    $dumpfile("tb_perceptron_hs.vcd");
`endif
    $dumpvars(0, tb_perceptron_hs);
    errors = 0; total_errors = 0; seed = 551;

    full_transaction(0, 0, 0, "T1 vec0 no stall");
    full_transaction(0, 1, 5, "T2 vec0 fixed stall 5");
    full_transaction(1, 0, 0, "T3 vec1 no stall");
    full_transaction(1, 2, 0, "T4 vec1 random stall");
    full_transaction(0, 2, 0, "T5 repeat random stall");

    // T6: reset in the middle of a stall, then recover
    set_vectors(1); compute_expected;
    apply_reset; load_weight_values; load_input_values; wait_for_data_ready;
    @(negedge globalClk) giveData = 1'b1;
    wait (busReq === 1'b1);
    @(negedge globalClk) giveData = 1'b0; busAck = 1'b0;
    repeat (4) @(negedge globalClk);
    if (busReq !== 1'b1) begin $display("ERROR: T6 not holding during stall"); total_errors = total_errors + 1; end
    resetAll = 1'b1;
    repeat (2) @(posedge globalClk); #1;
    if (
`ifndef GATE
        dut.I0.state !== 3'd0 ||
`endif
        busReq !== 1'b0 || dataBus !== 8'hZZ || dut.net6 !== 3'b000) begin
      $display("ERROR: T6 reset during stall did not clean up"); total_errors = total_errors + 1;
    end else $display("PASS: T6 reset during stall");
    full_transaction(0, 1, 3, "T6b recovery after reset");

    // T7-T10: additional vectors for coverage and switching activity (power VCD).
    // Appended after T1-T6b so the earlier waveform timestamps are unchanged.
    full_transaction(2, 0, 0, "T7 vec2 no stall");
    full_transaction(3, 2, 0, "T8 vec3 zeros rand stall");
    full_transaction(4, 1, 2, "T9 vec4 bits stall 2");
    full_transaction(5, 2, 0, "T10 vec5 max rand stall");

    if (total_errors == 0) $display("ALL TESTS PASSED");
    else                   $display("TESTS FAILED: %0d total error(s)", total_errors);
    $finish;
  end

endmodule
