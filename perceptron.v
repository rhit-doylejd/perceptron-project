//Verilog HDL for "ECE551Project", "perceptron" "functional"


module perceptron (

  input resetAll,
  input globalClk,
  input giveData,
  input readInputs,
  input readWeights,
  input busAck,
  output dataReady,
  output ackReadInputs,
  output ackDataSent,
  output ackReadWeights,
  output busReq,
  inout  [7:0] dataBus
);

wire  [7:0]  sig2out;
wire  [0:7]  net32;
wire  [0:7]  net30;
wire  [0:7]  net29;
wire  [0:2]  net6;
wire popOutC2O;


// Added port mapping so the positional mapping would stop breaking
controller I0 ( .clk(globalClk), .rstAll(resetAll), .readWts(readWeights),
     .readIns(readInputs), .giveData(giveData), .insFull(insFullI2C),
     .wtsFull(wtsFullI2C), .insCycled(insCycledI2C), .colDone(colDoneF2C),
     .outStatus(net6[0:2]), .busAck(busAck), .busReq(busReq), .popOut(popOutC2O),
     .ackRdWts(ackReadWeights), .ackRdIns(ackReadInputs), .ackDataSent(ackDataSent),
     .dataReady(dataReady), .rotWts(rotWtsC2W), .rotIns(rotInputsC2I), .rotMpy(rotMpyC2F),
     .rstWts(rstWtsC2W), .rstIns(rstInputsC2I), .rstOuts(rstOutC2O), .rstMpy(rstMpyC2F),
     .sendOuts(sendOutsC2O), .ldWts(loadWtsC2W), .ldIns(loadInputsC2I), .ldOuts(loadOutsC2O));
fmacc I1 ( globalClk, rstMpyC2F, rotMpyC2F, net30[0:7], net29[0:7],
     colDoneF2C, net32[0:7]);
inputFIFO I2 ( globalClk, rotInputsC2I, loadInputsC2I, rstInputsC2I,
     dataBus[7:0], insFullI2C, insCycledI2C, net30[0:7]);
outputFIFO I3 ( .clk(globalClk), .rst(rstOutC2O), .load(loadOutsC2O),
     .rotOut(popOutC2O), .busEn(sendOutsC2O), .fifoDataIn(sig2out[7:0]),
     .fifoStat(net6[0:2]), .fifoDataOut(dataBus[7:0]));
sigmoid I4 ( net32[0:7], sig2out[7:0]);
weightFIFO I5 ( globalClk, loadWtsC2W, rotWtsC2W, rstWtsC2W,
     dataBus[7:0], wtsFullI2C, net29[0:7]);


endmodule
