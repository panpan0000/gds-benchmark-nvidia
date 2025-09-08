# 压测脚本

| 脚本名称                              | 作用                                  | 示例                                        |
| --------------------------------- | ----------------------------------- | ----------------------------------------- |
| auto_benchmark.sh                 | 启动vllm-server，运行压测脚本 run.sh         | ./auto_benchmakr.sh                       |
| cache-offloading/run.sh           | 压测脚本，使用不同的参数运行 benchmark_serving.py | ./run.sh key1=val1 key2=val2              |
| rdma_monitor.py                   | rdma 网络流量监控脚本                       | python rdma_monitor.py                    |
| collect_and_plot.py               | 将压测的结果重新整理和命名，并且绘制三次迭代的折线图          | python collect_and_plot.py                |
| compare_offloading.py             | 汇总测试数据并生成CSV                        | python compare_offloading.py              |
| cache-offloading/lmcache/patch.sh | lmcache GDS bugfix patch            | ./patch.sh                                |
| plot_compare.py                   | 选取第三次迭代的数据绘制横向比较的折线图                | ./plot_compare.py mean_ttft_ms a1.json a2.json b1.json |
