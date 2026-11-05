What would be better is to implement a handshaking protocol between the outFIFO and the databus. Then if the FIFO is stalled by waiting for an ACK signal, you can stall the whole pipeline. That would be a more realistic proposal. Please come talk with me if you have questions or if this doesn’t make sense.

We will be given the baseline design numbers and those values to compare to.

Only need to get measurments for our design not the baseline design. 