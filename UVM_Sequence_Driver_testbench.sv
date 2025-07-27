// This example illustrates how to implement a unidirectional sequence-driver
// use model. The example used is an ADPCM like undirectional comms protocol.
// There is no response, so there is no DUT, just an interface ---->
//
// "Open EPWave after run" to see the signal traffic being sent.
package adpcm_pkg;//定义一个名为 adpcm_pkg 的包，把下面所有的 class、function 等内容打包管理，方便后续统一引用。
import uvm_pkg::*;//导入UVM包和UVM宏
`include "uvm_macros.svh"//包含UVM宏定义文件，提供了UVM的基本宏功能
// Sequence item contains the data and a delay before
// sending the data frame
class adpcm_seq_item extends uvm_sequence_item;// 定义一个名为 adpcm_seq_item 的类，继承自 uvm_sequence_item 类
rand logic[31:0] data;// 定义一个 32 位的随机逻辑数据字段，表示 ADPCM 数据帧
rand int delay;// 定义一个整数延迟字段，表示发送数据帧前的延迟时间
constraint c_delay { delay > 0; delay <= 20; }// 定义一个名字叫 c_delay 的约束，要求 delay 字段的随机值必须大于0、且小于等于20。
`uvm_object_utils(adpcm_seq_item)// 使用宏 `uvm_object_utils 来注册 adpcm_seq_item 类，使其可以被 UVM 工具识别和使用。
function new(string name = "adpcm_seq_item");// 构造函数，初始化 adpcm_seq_item 类的实例
  super.new(name);// 调用父类的构造函数，传入名称参数
endfunction
function void do_copy(uvm_object rhs);// 复制函数，将 rhs 的数据复制到当前对象，rhs 的全称就是Right Hand Side，意思是“右边的对象”。
  adpcm_seq_item rhs_;// 声明一个 adpcm_seq_item 类型的变量 rhs_，用于存储 rhs 的引用。

  if(!$cast(rhs_, rhs)) begin//用$cast尝试把rhs（基类指针）强制转换为adpcm_seq_item类型。如果失败，报错（说明类型不对）。$cast 是 SystemVerilog 的一个系统函数，用来把一个对象强制类型转换成目标类型。
    uvm_report_error("do_copy", "cast failed, check types");//
  end
  data = rhs_.data;// 将 rhs_ 的 data 字段值复制到当前对象的 data 字段
  delay = rhs_.delay;// 将 rhs_ 的 delay 字段值复制到当前对象的 delay 字段
endfunction: do_copy//do_copy 是 UVM 官方推荐你重写的一个虚函数
function bit do_compare(uvm_object rhs, uvm_comparer comparer);//声明一个名为do_compare的函数，它会返回一个bit型（1或0）的值，需要两个参数：一个是要比较的对象rhs，一个是UVM的比较工具comparer。
  adpcm_seq_item rhs_;
//只有所有条件都满足时，do_compare才为1，否则为0
  do_compare = $cast(rhs_, rhs) &&//尝试把rhs转成adpcm_seq_item类型，成功才往下比；失败直接返回0。
               super.do_compare(rhs, comparer) &&//调用父类的 do_compare 方法，比较父类里的所有字段是否相等
               data == rhs_.data &&//当前对象的data和rhs_的data要相等。
               delay == rhs_.delay;//当前对象的delay和rhs_的delay也要相等
endfunction: do_compare
function string convert2string();//把对象的数据内容转换成字符串，便于打印显示。
  return $sformatf(" data:\t%0h\n delay:\t%0d", data, delay);// 使用 $sformatf 函数格式化字符串，包含 data 和 delay 字段的值
endfunction: convert2string
function void do_print(uvm_printer printer);// 打印当前对象的内容到控制台或日志中

  if(printer.knobs.sprint == 0) begin//printer.knobs.sprint 是 UVM 系统自带的字段。
    $display(convert2string());
  end
  else begin
    printer.m_string = convert2string();
  end

endfunction: do_print
function void do_record(uvm_recorder recorder);// 记录当前对象的内容到日志中
  super.do_record(recorder);

  `uvm_record_field("data", data);
  `uvm_record_field("delay", delay);

endfunction: do_record
endclass: adpcm_seq_item
// Unidirectional driver uses the get_next_item(), item_done() approach
class adpcm_driver extends uvm_driver #(adpcm_seq_item);

`uvm_component_utils(adpcm_driver)

adpcm_seq_item req;

virtual adpcm_if.mon_mp ADPCM;// 声明一个虚接口 ADPCM，用于与外部接口进行通信

function new(string name = "adpcm_driver", uvm_component parent = null);// 构造函数，初始化 adpcm_driver 类的实例
  super.new(name, parent);
endfunction

task run_phase(uvm_phase phase);// 运行阶段任务，驱动器的主要逻辑在这里执行
  int top_idx = 0;

  // Default conditions:
  ADPCM.cb.frame <= 0;
  ADPCM.cb.data <= 0;
  fork//开始一个并行执行的任务
  forever//主驱动 forever 块（发送激励）
    begin
      seq_item_port.get_next_item(req); //等待并获取下一个激励项（req）：seq_item_port.get_next_item(req)
      repeat(req.delay) begin // 按req.delay空跑delay个周期
        @(ADPCM.cb);// 等待时钟周期
      end
      ADPCM.cb.frame <= 1; // 开始新的一帧
      for(int i = 0; i < 8; i++) begin //for循环8次，每次发4位数据（从req.data的最低4位开始，右移取出）
        @(ADPCM.cb);
        ADPCM.cb.data <= req.data[3:0];// 取出 req.data 的最低4位
        req.data = req.data >> 4;// 将 req.data 右移4位，准备下一次发送
      end
      ADPCM.cb.frame <= 0; //帧结束（frame=0）
      seq_item_port.item_done(); //通知sequence，这个激励项已处理完
    end
  forever begin//监控 forever 块（打印时间戳）
    @(ADPCM.cb);
    if (ADPCM.cb.frame === 1'b1) begin
      $display($time);
    end
  end
  join_none// 结束并行任务
endtask: run_phase

endclass: adpcm_driver
class adpcm_sequencer extends uvm_sequencer #(adpcm_seq_item);// 定义一个名为 adpcm_sequencer 的类，继承自 uvm_sequencer 类，使用 adpcm_seq_item 作为序列项类型

`uvm_component_utils(adpcm_sequencer)

function new(string name = "adpcm_sequencer", uvm_component parent = null);
  super.new(name, parent);
endfunction

endclass: adpcm_sequencer
// Sequence part of the use model
// The sequence randomizes 10 ADPCM data packets and sends
class adpcm_tx_seq extends uvm_sequence #(adpcm_seq_item);

`uvm_object_utils(adpcm_tx_seq)

// ADPCM sequence_item
adpcm_seq_item req;

// Controls the number of request sequence items sent
rand int no_reqs = 10;

function new(string name = "adpcm_tx_seq");
  super.new(name);
  // do_not_randomize = 1'b1; // Required for ModelSim
endfunction

task body;//task body 负责循环生成多组随机激励，每次把 delay 和 data 随机赋值后，按流程发送给 driver。
  req = adpcm_seq_item::type_id::create("req");//创建一个adpcm_seq_item对象，名字叫"req"，以后用于发送给driver。
  for(int i = 0; i < no_reqs; i++) begin
    start_item(req);//通知UVM“我要开始生成一个事务激励”。
    // req.randomize();
    // For ModelSim, use $urandom to achieve randomization for your request
    req.delay = $urandom_range(1, 20);// 使用 $urandom_range 生成一个随机延迟，范围从1到20
    req.data = $urandom();// 使用 $urandom 生成一个随机数据
    finish_item(req);//通知UVM“我已经完成了这个事务激励的生成”，并将req发送给driver。
    `uvm_info("ADPCM_TX_SEQ_BODY", $sformatf("Transmitted frame %0d", i), UVM_LOW)
  end
endtask: body

endclass: adpcm_tx_seq
// Test instantiates, builds and connects the driver and the sequencer
// then runs the sequence
class adpcm_test extends uvm_test;

`uvm_component_utils(adpcm_test)

adpcm_tx_seq test_seq;// 声明一个 adpcm_tx_seq 类型的变量 test_seq，用于存储测试序列
adpcm_driver m_driver;// 声明一个 adpcm_driver 类型的变量 m_driver，用于驱动 ADPCM 接口
adpcm_sequencer m_sequencer;// 声明一个 adpcm_sequencer 类型的变量 m_sequencer，用于发送序列项

function new(string name = "adpcm_test", uvm_component parent = null);// 构造函数，初始化 adpcm_test 类的实例
  super.new(name, parent);
endfunction

function void build_phase(uvm_phase phase);// 构建阶段，创建驱动器和序列器的实例
  m_driver = adpcm_driver::type_id::create("m_driver", this);// 创建 adpcm_driver 的实例 m_driver
  m_sequencer = adpcm_sequencer::type_id::create("m_sequencer", this);// 创建 adpcm_sequencer 的实例 m_sequencer
endfunction: build_phase

function void connect_phase(uvm_phase phase);// 连接阶段，将驱动器和序列器连接起来
  m_driver.seq_item_port.connect(m_sequencer.seq_item_export);// 连接driver和sequencer，将 m_driver 的 seq_item_port 连接到 m_sequencer 的 seq_item_export
  if (!uvm_config_db #(virtual adpcm_if.mon_mp)::get(this, "", "ADPCM_vif", m_driver.ADPCM)) begin// 从配置数据库中获取虚拟接口 ADPCM_vif，如果未找到，则报错
    `uvm_error("connect", "ADPCM_vif not found")
  end
endfunction: connect_phase

task run_phase(uvm_phase phase);
  test_seq = adpcm_tx_seq::type_id::create("test_seq");// 生成要执行的测试序列
  phase.raise_objection(this, "starting test_seq");// 提出“反对”（objection），告诉UVM仿真系统测试还没跑完，不要提前结束
  test_seq.start(m_sequencer);// 启动测试序列 test_seq，并将其发送到 m_sequencer
  phase.drop_objection(this, "finished test_seq");// 撤销“反对”，告诉UVM系统测试已经结束，可以结束仿真。
endtask: run_phase

endclass: adpcm_test
endpackage: adpcm_pkg


module top_tb;// 顶层测试模块，包含时钟生成和 UVM 测试环境的初始化

import uvm_pkg::*;
import adpcm_pkg::*;

adpcm_if ADPCM();// 声明一个 adpcm_if 类型的虚接口 ADPCM，用于与外部接口进行通信

// Free running clock
initial// 初始化时钟信号
  begin
    ADPCM.clk = 0;
    forever begin
      #10 ADPCM.clk = ~ADPCM.clk;
    end
  end

// UVM start up:
initial// 初始化 UVM 测试环境
  begin
    uvm_config_db #(virtual adpcm_if.mon_mp)::set(null, "uvm_test_top", "ADPCM_vif" , ADPCM);// 将虚拟接口 ADPCM 设置到 UVM 配置数据库中，以便后续使用
    run_test("adpcm_test");// 启动 UVM 测试，运行名为 "adpcm_test" 的测试类
  end
  
// Dump waves
  initial $dumpvars(0, top_tb);// 初始化波形转储，记录仿真波形数据

endmodule: top_tb
