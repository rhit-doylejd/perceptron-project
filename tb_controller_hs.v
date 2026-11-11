`timescale 1ns/1ps
// Module-level self-checking testbench for controller.v
// Exercises the redesigned 4-phase busReq/busAck output handshake in isolation:
//   SENDDATA -> (busAck) -> popOut + WAIT_ACK_LOW -> (!busAck) -> SENDDATA / IDLE
//
// The outputFIFO is replaced by a small behavioral model of its valid bits
// ({R0,R1,R2} = outStatus) so the testbench controls exactly when the
// controller sees results pending, stalls, and empties.
//
// Run (from sim/):
//   xrun -access +rwc ../tb_controller_hs.v ../controller.v
module tb_controller_hs;

  localparam INIT = 3'd0, IDLE = 3'd1, LDWTS = 3'd2, LDINS = 3'd3,
             DOMPY = 3'd4, SENDDATA = 3'd5, WAIT_ACK_LOW = 3'd6;

  reg        clk, rstAll, readWts, readIns, giveData;
  reg        insFull, wtsFull, insCycled, colDone, busAck;
  reg  [2:0] outStatus;
  wire       busReq, popOut, pipelineStall;
  wire       ackRdWts, ackRdIns, ackDataSent, dataReady;
  wire       rotWts, rotIns, rotMpy, rstWts, rstIns, rstOuts, rstMpy;
  wire       sendOuts, ldWts, ldIns, ldOuts;

  integer errors, pops;

  controller dut (
    .clk(clk), .rstAll(rstAll), .readWts(readWts), .readIns(readIns),
    .giveData(giveData), .insFull(insFull), .wtsFull(wtsFull),
    .insCycled(insCycled), .colDone(colDone), .outStatus(outStatus),
    .busAck(busAck), .busReq(busReq), .popOut(popOut), .pipelineStall(pipelineStall),
    .ackRdWts(ackRdWts), .ackRdIns(ackRdIns), .ackDataSent(ackDataSent),
    .dataReady(dataReady), .rotWts(rotWts), .rotIns(rotIns), .rotMpy(rotMpy),
    .rstWts(rstWts), .rstIns(rstIns), .rstOuts(rstOuts), .rstMpy(rstMpy),
    .sendOuts(sendOuts), .ldWts(ldWts), .ldIns(ldIns), .ldOuts(ldOuts)
  );

  initial begin clk = 1'b0; forever #5 clk = ~clk; end
  initial begin #50000; $display("[%0t] ERROR: simulation timeout", $time); $finish; end

  //------------------------------------------------------------
  // Behavioral outputFIFO valid bits, same shift rules as outputFIFO.v:
  //   load: {R0,R1,R2} <= {1, R0, R1}    pop: {R0,R1,R2} <= {0, R0, R1}
  //------------------------------------------------------------
  always @(posedge clk) begin
    if (rstOuts)      outStatus <= 3'b000;
    else if (ldOuts)  outStatus <= {1'b1, outStatus[2:1]};
    else if (popOut)  outStatus <= {1'b0, outStatus[2:1]};
  end

  // Count FIFO advances (one per accepted byte)
  always @(posedge clk) if (popOut === 1'b1) pops = pops + 1;

  //------------------------------------------------------------
  // Helpers. Inputs change just after a negedge; checks run 1 ns later.
  //------------------------------------------------------------
  task check;
    input        cond;
    input [8*56-1:0] msg;
    begin
      if (cond !== 1'b1) begin
        $display("[%0t] ERROR: %0s (state=%0d outStatus=%b busAck=%b busReq=%b popOut=%b)",
                 $time, msg, dut.state, outStatus, busAck, busReq, popOut);
        errors = errors + 1;
      end
    end
  endtask

  task next_cycle;
    begin @(negedge clk); #1; end
  endtask

  // From IDLE with both banks full: DOMPY computes and loads three results
  task do_compute;
    integer k;
    begin
      insFull = 1'b1; wtsFull = 1'b1; #1;
      check(rstMpy === 1'b1, "IDLE asserts rstMpy when starting a compute");
      next_cycle;
      check(dut.state === DOMPY, "IDLE -> DOMPY when banks full and outputs empty");
      check(pipelineStall === 1'b0, "pipelineStall low in DOMPY");
      check(rotIns === 1'b1 && rotWts === 1'b1, "DOMPY rotates input and weight banks");
      for (k = 0; k < 3; k = k + 1) begin
        next_cycle;                                   // a plain MAC cycle
        insCycled = 1'b1; colDone = 1'b1; #1;
        check(rotMpy === 1'b1 && ldOuts === 1'b1, "rotMpy/ldOuts on insCycled & colDone");
        @(negedge clk); insCycled = 1'b0; colDone = 1'b0; #1;
      end
      check(outStatus === 3'b111, "three results loaded into output FIFO");
      check(rotIns === 1'b0 && rotWts === 1'b0 && ldOuts === 1'b0,
            "DOMPY stops rotating once outputs are full");
      insFull = 1'b0; wtsFull = 1'b0;                 // real input valid bits clear after compute
      next_cycle;
      check(dut.state === IDLE, "DOMPY -> IDLE when outputs full");
      check(dataReady === 1'b1, "dataReady set after compute");
    end
  endtask

  // Send three bytes. stall = cycles the receiver waits before raising busAck;
  // hold = extra cycles the receiver keeps busAck high after the controller drops busReq.
  task do_send;
    input integer stall;
    input integer hold;
    integer b, k, cyc;
    begin
      pops = 0; cyc = 0;
      giveData = 1'b1;
      @(negedge clk); giveData = 1'b0; #1; cyc = cyc + 1;
      check(dut.state === SENDDATA, "IDLE -> SENDDATA on giveData");
      check(ackDataSent === 1'b0, "ackDataSent cleared when a send starts");

      for (b = 0; b < 3; b = b + 1) begin
        for (k = 0; k < stall; k = k + 1) begin
          check(busReq === 1'b1 && sendOuts === 1'b1, "busReq/sendOuts high while awaiting ack");
          check(popOut === 1'b0, "no FIFO pop while receiver stalls");
          check(dut.state === SENDDATA, "controller holds SENDDATA while stalled");
          check(pipelineStall === 1'b1, "pipelineStall high outside DOMPY");
          check(ackDataSent === 1'b0, "no ackDataSent mid-transfer");
          next_cycle; cyc = cyc + 1;
        end
        check(busReq === 1'b1, "busReq high before ack");
        busAck = 1'b1; #1;
        check(popOut === 1'b1, "popOut asserted with busAck in SENDDATA");
        next_cycle; cyc = cyc + 1;
        check(dut.state === WAIT_ACK_LOW, "SENDDATA -> WAIT_ACK_LOW on busAck");
        check(busReq === 1'b0 && popOut === 1'b0, "busReq and popOut low in WAIT_ACK_LOW");
        for (k = 0; k < hold; k = k + 1) begin
          next_cycle; cyc = cyc + 1;
          check(dut.state === WAIT_ACK_LOW && popOut === 1'b0,
                "waits (no second pop) while busAck stays high");
        end
        busAck = 1'b0;
        next_cycle; cyc = cyc + 1;
        if (b < 2)
          check(dut.state === SENDDATA, "busAck low -> SENDDATA for next byte");
      end

      check(dut.state === IDLE, "last byte -> IDLE");
      check(ackDataSent === 1'b1, "ackDataSent after last byte");
      check(dataReady === 1'b0, "dataReady cleared after send");
      check(outStatus === 3'b000, "output FIFO empty after send");
      check(pops == 3, "exactly one popOut per byte");
      $display("[%0t] send (stall=%0d, hold=%0d) took %0d cycles, %0d pops",
               $time, stall, hold, cyc, pops);
    end
  endtask

  //------------------------------------------------------------
  // Main test sequence
  //------------------------------------------------------------
  initial begin
    $dumpfile("tb_controller_hs.vcd");
    $dumpvars(0, tb_controller_hs);

    errors = 0; pops = 0;
    rstAll = 1'b1; readWts = 1'b0; readIns = 1'b0; giveData = 1'b0;
    insFull = 1'b0; wtsFull = 1'b0; insCycled = 1'b0; colDone = 1'b0; busAck = 1'b0;
    outStatus = 3'b000;

    // C1: reset
    repeat (3) @(negedge clk); #1;
    check(dut.state === INIT, "C1 state INIT during reset");
    check(rstIns && rstOuts && rstMpy && rstWts, "C1 INIT asserts all datapath resets");
    check(busReq === 1'b0 && sendOuts === 1'b0 && popOut === 1'b0, "C1 no bus activity in reset");
    rstAll = 1'b0;
    next_cycle;
    check(dut.state === IDLE, "C1 INIT -> IDLE after reset release");
    check(ackDataSent === 1'b0 && dataReady === 1'b0, "C1 status registers cleared");
    $display("C1 reset done");

    // C2: compute fills the output FIFO
    do_compute;
    $display("C2 compute done");

    // C3: backpressure - results still pending must block a new compute
    insFull = 1'b1; wtsFull = 1'b1;
    repeat (3) begin
      next_cycle;
      check(dut.state === IDLE && rstMpy === 1'b0, "C3 no new compute while results pending");
    end
    insFull = 1'b0; wtsFull = 1'b0;
    $display("C3 backpressure done");

    // C4: stalled receiver (4 cycles before each ack) that is slow to drop ack (2 cycles)
    do_send(4, 2);
    $display("C4 stalled send done");

    // C5: second transaction, no stalls (best case, 2 cycles per byte)
    do_compute;
    do_send(0, 0);
    $display("C5 back-to-back transaction done");

    // C6: giveData with nothing to send must not raise busReq
    giveData = 1'b1;
    @(negedge clk); giveData = 1'b0; #1;
    check(busReq === 1'b0 && popOut === 1'b0, "C6 empty send: no busReq/popOut");
    next_cycle;
    check(dut.state === IDLE, "C6 empty send returns to IDLE");
    $display("C6 empty send done");

    // C7: reset in the middle of a stall
    do_compute;
    giveData = 1'b1;
    @(negedge clk); giveData = 1'b0; #1;
    repeat (3) @(negedge clk); #1;
    check(busReq === 1'b1 && dut.state === SENDDATA, "C7 stalled with busReq high");
    rstAll = 1'b1;
    next_cycle;
    check(dut.state === INIT && busReq === 1'b0 && sendOuts === 1'b0 && popOut === 1'b0,
          "C7 reset mid-stall -> INIT, bus released");
    next_cycle;
    check(outStatus === 3'b000, "C7 rstOuts clears the output FIFO");
    rstAll = 1'b0;
    next_cycle;
    check(dut.state === IDLE, "C7 recovers to IDLE");
    check(ackDataSent === 1'b0 && dataReady === 1'b0, "C7 status registers cleared");
    $display("C7 reset mid-stall done");

    if (errors == 0) $display("ALL CONTROLLER TESTS PASSED");
    else             $display("CONTROLLER TESTS FAILED: %0d error(s)", errors);
    $finish;
  end

endmodule
