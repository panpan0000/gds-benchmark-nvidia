# KVCache Benchmark Results (2025-09-01-pd)

本轮测试是在 2025-08-22 的基础上补测的，主要是重新测试了一轮不开启arcc时，带上decoding的性能表现，另外增加了GDS 800Gps的场景，其他参数均保持一致。

| 编号| Offloading 方式 |  带宽  |     ARCC 开启     |
| --- | ----------- | ----- | -------------------- |
| 1  |   Local Disk |  400Gbps      |       N      |
| 2  |   Local Disk |  800Gbps      |       N      |
| 3  |   GDS        |  400Gbps      |       N      |
| 4  |   GDS        |  800Gbps      |       N      |

## 部署参数

除了硬件上的差异，我们采用相同的部署参数来进行压测

- vLLM 通用参数：TP=8，关闭前缀缓存，使用LMCacheConnectorV1 (--tensor-parallel-size 8 --no-enable-prefix-caching --disable-log-requests -kv-transfer-config '{\"kv_connector\":\"LMCacheConnectorV1\", \"kv_role\":\"kv_both\"}')
- LMCache：chunk_size=256，**max_local_cpu_size=50.0**

更详细信息可以参考： [auto_benchmark.sh](../tools/auto_benchmark.sh)

## 压测参数

我们使用vllm benchmarks/benchmark_serving.py 来进行压测，每组部署配置测试三轮，使用Random数据集和固定的Seed（以保证每轮tokens相同），其他压测参数如下：

- 并发数：16
- 输入长度：100/1k/10k/50k/100k
- **输出长度：20**
- **迭代数：20**

(作为参考，全部压测完生成的kv cache大约是1.1TB)

更多详细信息可以参考： [run.sh](../tools/run.sh)
