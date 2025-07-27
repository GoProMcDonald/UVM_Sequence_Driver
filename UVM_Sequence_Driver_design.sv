interface adpcm_if;

logic clk;
logic frame;
logic[3:0] data;
logic bozo;
  
  clocking cb @(posedge clk);// 定义一个时钟域 cb，基于上升沿的时钟 clk
    inout frame;
    //input other;
    inout data;
  endclocking
  
  modport mon_mp (clocking cb);// 定义一个监控模式 mon_mp，使用 cb 时钟域

endinterface: adpcm_if
