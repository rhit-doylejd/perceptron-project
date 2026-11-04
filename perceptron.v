//Verilog HDL for "ECE551Project", "perceptron" "functional"


module perceptron (

  input resetAll,
  input globalClk,
  input giveData,
  input readInputs,
  input readWeights,
  output dataReady,
  output ackReadInputs,
  output ackDataSent,
  output ackReadWeights,
  inout  [7:0] dataBus
);

wire  [7:0]  sig2out;
wire  [0:7]  net32;
wire  [0:7]  net30;
wire  [0:7]  net29;
wire  [0:2]  net6;


controller I0 ( globalClk, resetAll, readWeights, readInputs, giveData,
     insFullI2C, wtsFullI2C, insCycledI2C, colDoneF2C, net6[0:2],
     ackReadWeights, ackReadInputs, ackDataSent, dataReady, rotWtsC2W,
     rotInputsC2I, rotMpyC2F, rstWtsC2W, rstInputsC2I, rstOutC2O,
     rstMpyC2F, sendOutsC2O, loadWtsC2W, loadInputsC2I, loadOutsC2O);
fmacc I1 ( globalClk, rstMpyC2F, rotMpyC2F, net30[0:7], net29[0:7],
     colDoneF2C, net32[0:7]);
inputFIFO I2 ( globalClk, rotInputsC2I, loadInputsC2I, rstInputsC2I,
     dataBus[7:0], insFullI2C, insCycledI2C, net30[0:7]);
outputFIFO I3 ( globalClk, rstOutC2O, loadOutsC2O, sendOutsC2O,
     sig2out[7:0], net6[0:2], dataBus[7:0]);
sigmoid I4 ( net32[0:7], sig2out[7:0]);
weightFIFO I5 ( globalClk, loadWtsC2W, rotWtsC2W, rstWtsC2W,
     dataBus[7:0], wtsFullI2C, net29[0:7]);


endmodule
