       module alu (
  input  logic       clk, rst_n,
  input  logic       valid_in,
  input  logic [7:0] a, b,
  input  logic [1:0] op,        // 0=ADD, 1=SUB, 2=AND, 3=XOR
  output logic       valid_out,
  output logic [8:0] result     // 9 bits to hold the carry
);
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      valid_out <= 0;
      result    <= 0;
    end else begin
      valid_out <= valid_in;
      if (valid_in)
        case (op)
          2'd0: result <= a + b;
          2'd1: result <= a - b;
          2'd2: result <= a & b;
          2'd3: result <= a ^ b;
        endcase
    end
  end
endmodule
