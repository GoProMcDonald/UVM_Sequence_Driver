# UVM Sequence-Driver Example

## 项目简介

本项目演示如何使用 SystemVerilog + UVM 实现**单向 Sequence-Driver 通信模型**，适用于学习 UVM 基础的 transaction 流程、driver 实现与仿真波形分析。  
本例未包含 DUT（无被测对象），仅演示 sequence 到 driver 的数据流，所有信号通过接口 interface 驱动。适合初学 UVM 框架、理解基础通信原理。

---

## 主要内容

- **package adpcm_pkg**：定义所有 class、function 及 transaction。
- **interface**：作为连接 sequence/driver 的桥梁。
- **sequence/driver**：实现基本 transaction 生成与信号驱动。
- **testbench**：启动 UVM 仿真流程，可通过 EPWave 观察波形。

---

<img width="1843" height="141" alt="image" src="https://github.com/user-attachments/assets/277d0654-3f7b-4df2-93c6-b9ff7e7048fb" />

