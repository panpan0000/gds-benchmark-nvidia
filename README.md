# KV Cache Offloading Benchmark

| 编号| 测试方式     |  测试场景  |     备注     | 方向  |
| --- | ----------- | ----- | -------------------- | ---------- |
| [0821](./benchmark_result_0821/)  |   prefill only    |  CPU<br>400Gbps Disk w/ or w/o arcc<br>800Gbps Disk w/ or w/o arcc<br>400Gbps GDS w/ arcc       |      测试Disk时同时开启了CPU offloading     | N/A |
| [0822](./benchmark_result_0822/)  |   prefill+decode  |  NO KVCache<br>CPU<br>400Gbps Disk w/ arcc<br>800Gbps Disk w/ arcc<br>400Gbps GDS w/ arcc      |      测试Disk时同时开启了CPU offloading    | N/A |
| [0901-pd](./benchmark_result_0901_pd/)  |   prefill+decode  |  400Gbps Disk w/o arcc<br>800Gbps Disk w/o arcc<br>400Gbps GDS w/o arcc<br>800Gbps GDS w/o arcc      |      测试Disk时同时开启了CPU offloading    | N/A |
| [0901-prefill](./benchmark_result_0901_prefill/)  |   prefill only  |  400Gbps Disk w/o arcc<br>800Gbps Disk w/o arcc<br>400Gbps GDS w/o arcc<br>800Gbps GDS w/o arcc      |      测试Disk时同时开启了CPU offloading    | N/A |
| [0908](./benchmark_result_0908/) |   prefill only  |  800Gbps Disk w/o arcc<br>400Gbps GDS w/o arcc<br>800Gbps GDS w/o arcc      |     关闭CPU offloading，定长input len变长prompt num，迭代100轮     | N/A |
| [0910](./benchmark_result_0910/)  |   prefill only  |  400Gbps Disk w/o arcc<br>800Gbps Disk w/o arcc<br>400Gbps GDS w/o arcc<br>800Gbps GDS w/o arcc   |     关闭CPU offloading，迭代10轮      | 东西向 |
| [0912](./benchmark_result_0912<br>)  |   prefill only  |  800Gbps Disk w/ or w/o arcc<br>800Gbps GDS w/ or w/o arcc      |     关闭CPU offloading，迭代10轮，只测了100k input len   | 南北向 |
| [0914](./benchmark_result_0914/)  |   prefill only  |  800Gbps Disk w/ arcc<br>800Gbps GDS w/ arcc      |     关闭CPU offloading，迭代10轮，只测了100k input len | 东西向 |

> 1. 测试Disk时同时开启了CPU offloading时设置内存为100G;
> 2. 定长input len变长prompt num时是为了追求KV Cache size按照50G/100G/150G/200G/250G变化;
> 3. 前几次测试默认都是南北向，但是由于没有监控无法100%确认；

