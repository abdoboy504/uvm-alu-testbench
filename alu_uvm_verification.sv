interface dut_if(input logic clk);
     
logic       rst_n;
logic       valid_in;
logic [7:0] a, b;
logic [1:0] op;
logic       valid_out;
logic [8:0] result;
     
     clocking drv_cb @(posedge clk);  
       default input #1step output #1ns;
       output valid_in,  a, b, op;
       input  valid_out, result;    // testbench reads these
     endclocking
     
   clocking mon_cb @(posedge clk);  
    default input #1step ;
    input valid_in, a, b, op,valid_out, result;   
  endclocking 
  endinterface 
package pkg;
import uvm_pkg::*;
  `include "uvm_macros.svh"

class alu_item extends uvm_sequence_item;
  `uvm_object_utils(alu_item)
  // fields 
    rand bit [7:0] a, b;
    rand bit [1:0] op;
    bit [8:0] result;
  // construct
  function new(string name = "alu_item");
    super.new(name);
  endfunction
  // string formating for better value display 
  function string convert2string();
    return $sformatf("a=%0d b=%0d op=%0d result=%0d", a, b, op, result);
  endfunction

  endclass
class alu_driver extends uvm_driver#(alu_item);
  `uvm_component_utils(alu_driver)
  
  virtual dut_if vif;
  
  function new(string name = "alu_driver",uvm_component parent);
    super.new(name, parent);
  endfunction
     function void build_phase(uvm_phase phase);
    super.build_phase(phase);
       if(!uvm_config_db #(virtual dut_if)::get(this, "", "vif", vif))
         `uvm_fatal("NOVIF", "vif not set")
     endfunction
  
  task run_phase(uvm_phase phase);
     
      
        vif.drv_cb.a <= 8'b00000000;
        vif.drv_cb.b <= 8'b00000000;
        vif.drv_cb.valid_in <= 1'b0;
        vif.drv_cb.op <= 2'b00;
      
  forever begin
    seq_item_port.get_next_item(req);
    @(vif.drv_cb);
	vif.drv_cb.valid_in  <= 1;
	vif.drv_cb.a  <= req.a;
	vif.drv_cb.b  <= req.b;
	vif.drv_cb.op <= req.op;
    @(vif.drv_cb);
	vif.drv_cb.valid_in  <= 0;
    seq_item_port.item_done();
  end   
      endtask
       endclass
       
       class alu_monitor extends uvm_monitor;
  `uvm_component_utils(alu_monitor)

  virtual dut_if vif;
  uvm_analysis_port #(alu_item) ap;

  function new(string name = "alu_monitor", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(!uvm_config_db #(virtual dut_if)::get(this, "", "vif", vif))
         `uvm_fatal("NOVIF", "vif not set")
    ap = new("ap", this);
  endfunction

task run_phase(uvm_phase phase);
  alu_item  item;
  bit [7:0] prev_a, prev_b;
  bit [1:0] prev_op;

  forever begin
    @(vif.mon_cb);

    // 1. output side: a result is available
    if (vif.mon_cb.valid_out) begin
      item        = alu_item::type_id::create("item");
      item.a      = prev_a;
      item.b      = prev_b;
      item.op     = prev_op;
      item.result = vif.mon_cb.result;
      `uvm_info("MON", item.convert2string(), UVM_LOW)
      ap.write(item);
    end

    // 2. input side: remember the inputs for the next cycle
    if (vif.mon_cb.valid_in) begin
      prev_a  = vif.mon_cb.a;
      prev_b  = vif.mon_cb.b;
      prev_op = vif.mon_cb.op;
    end
  end
endtask
endclass
       
       
       
       typedef  uvm_sequencer #(alu_item) alu_sequencer;
       class alu_agent extends uvm_agent;
         `uvm_component_utils(alu_agent)

         alu_monitor mon;
         alu_driver drv;
         alu_sequencer sq;
         //constructor
         function new(string name, uvm_component parent);
         super.new(name, parent);
         endfunction

        function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        drv = alu_driver::type_id::create("drv", this);
        mon = alu_monitor::type_id::create("mon", this);
        sq = alu_sequencer::type_id::create("sq", this);
        endfunction

        function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        drv.seq_item_port.connect(sq.seq_item_export);
        endfunction

       endclass
       
       class alu_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(alu_scoreboard)

  uvm_analysis_imp #(alu_item, alu_scoreboard) imp;

  int pass_count;
  int fail_count;

  function new(string name = "alu_scoreboard", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    imp = new("imp", this);
    pass_count = 0;
    fail_count = 0;
  endfunction

  // called by the monitor's ap.write(item)
  function void write(alu_item t);
    bit [8:0] expected;

    case (t.op)
      2'd0:    expected = t.a + t.b;
      2'd1:    expected = t.a - t.b;
      2'd2:    expected = t.a & t.b;
      2'd3:    expected = t.a ^ t.b;
      default: expected = 0;
    endcase

    if (expected == t.result)
      pass_count++;
    else begin
      fail_count++;
      `uvm_error("MISMATCH",
                 $sformatf("expected: %0d actual: %0d (%s)",
                           expected, t.result, t.convert2string()))
    end
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("SB",
              $sformatf("PASS: %0d  FAIL: %0d", pass_count, fail_count),
              UVM_LOW)
  endfunction
endclass
       

 class alu_env extends uvm_env;
`uvm_component_utils(alu_env)

alu_agent myAgent;
alu_scoreboard myScoreboard;

function new(string name, uvm_component parent);
    super.new(name, parent);
endfunction

function void build_phase(uvm_phase phase);
super.build_phase(phase);
myAgent = alu_agent::type_id::create("myAgent", this);
myScoreboard = alu_scoreboard::type_id::create("myScoreboard", this);
endfunction

function void connect_phase(uvm_phase phase);
  super.connect_phase(phase);
  myAgent.mon.ap.connect(myScoreboard.imp);
endfunction
 endclass
       
       class alu_random_seq extends uvm_sequence #(alu_item);
  `uvm_object_utils(alu_random_seq)

  function new(string name = "alu_random_seq");
    super.new(name);
  endfunction

  task body();
    alu_item item;

    repeat (100) begin
    item = alu_item::type_id::create("item");
     start_item(item);
    if(!item.randomize())
        `uvm_error("RAND", "randomization failed")
    finish_item(item);
     end
  endtask
endclass
       
       
       class alu_test extends uvm_test;
  `uvm_component_utils(alu_test)

  alu_env env;

  function new(string name = "alu_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env= alu_env::type_id::create("env", this);
      endfunction

  task run_phase(uvm_phase phase);
    alu_random_seq seq;

    phase.raise_objection(this);    
    seq= alu_random_seq::type_id::create("seq");
    seq.start(env.myAgent.sq);
    #100ns;
    phase.drop_objection(this);    
  endtask
endclass

         
  endpackage
       
       
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
       
       
    module top;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import pkg::*;

  logic clk;
 initial clk =0;
  always #5 clk = ~clk;

dut_if myIf(clk);
  alu myAlu(
    .a(myIf.a),
    .b(myIf.b),
    .op(myIf.op),
    .valid_in(myIf.valid_in),
    .valid_out(myIf.valid_out),
    .result(myIf.result),
    .clk(clk),
    .rst_n(myIf.rst_n)
  );
initial 
begin 
    myIf.rst_n = 0;
    #10;
    myIf.rst_n = 1;
end
initial 
  begin
  uvm_config_db #(virtual dut_if)::set(null, "*", "vif", myIf);
  run_test("alu_test");
  end
endmodule
