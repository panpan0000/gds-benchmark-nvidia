# KVCache Benchmark Results (2025-09-12)

本轮测试主要是关闭了CPU offloading的场景，重测南北向100k token长度下，开启和关闭arcc时，800Gbps带宽的差异。此外为了保证结果稳定性，所有场景均测试了10轮，取2~10轮的平均值作为最终结果。


| 编号| Offloading 方式 |  带宽  |     ARCC 开启     |
| --- | ----------- | ----- | -------------------- |
| 1  |   Local Disk |  800Gbps      |       N      |
| 2  |   GDS        |  400Gbps      |       N      |
| 3  |   Local Disk        |  800Gbps      |       Y      |
| 4  |   GDS        |  800Gbps      |       Y      |


## 部署参数

除了硬件上的差异，我们采用相同的部署参数来进行压测

- vLLM 通用参数：TP=8，关闭前缀缓存，使用LMCacheConnectorV1 (--tensor-parallel-size 8 --no-enable-prefix-caching --disable-log-requests -kv-transfer-config '{\"kv_connector\":\"LMCacheConnectorV1\", \"kv_role\":\"kv_both\"}')
- LMCache：chunk_size=256

更详细信息可以参考： [auto_benchmark.sh](../tools/auto_benchmark.sh)

## 压测参数

我们使用vllm benchmarks/benchmark_serving.py 来进行压测，每组部署配置测试十轮，使用Random数据集和固定的Seed（以保证每轮tokens相同），其他压测参数如下：

- 并发数：16
- 输入长度：100k
- 输出长度：1
- 迭代数：10
- prompt num：50

更多详细信息可以参考： [run.sh](../tools/run.sh)
