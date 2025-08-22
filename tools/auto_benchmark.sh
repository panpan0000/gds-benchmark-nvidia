#!/bin/bash
set -e

IMAGE="lmcache/vllm-openai:v0.3.3"
CONTAINER_NAME="offloading-test"
HOST_IP="10.20.10.2"
MODEL_PATH="/models/DeepSeek-R1-0528"
TP_SIZE=8

# 挂载参数
MOUNTS=(
    -v "/root/daocloud/lmcache:/config"
    -v "/root/daocloud/src:/src"
    -v "/mnt/data:/models"
    -v "/400Gb:/mnt/afs"
)

VLLM_COMMON_ARGS="/opt/venv/bin/vllm serve $MODEL_PATH --served-model-name deepseek-ai/deepseek-r1-0528 --tensor-parallel-size $TP_SIZE --no-enable-prefix-caching --disable-log-requests"
LMCACHE_COMMON_ARGS="LMCACHE_USE_EXPERIMENTAL=True LMCACHE_CHUNK_SIZE=256 LMCACHE_MAX_LOCAL_CPU_SIZE=100.0"

# 启动命令数组
CMD1="$LMCACHE_COMMON_ARGS LMCACHE_LOCAL_DISK=\"file:///mnt/afs/cache/deepseek-r1-file/\" LMCACHE_MAX_LOCAL_DISK_SIZE=5000.0 $VLLM_COMMON_ARGS --kv-transfer-config '{\"kv_connector\":\"LMCacheConnectorV1\", \"kv_role\":\"kv_both\"}'"
CMD2="$LMCACHE_COMMON_ARGS $VLLM_COMMON_ARGS --kv-transfer-config '{\"kv_connector\":\"LMCacheConnectorV1\", \"kv_role\":\"kv_both\"}'"
CMD3="$VLLM_COMMON_ARGS"

CMDS=($CMD1 "$CMD2" "$CMD3")

run_benchmark() {
    echo "Running benchmark..."
    bash /root/daocloud/src/vllm-benchmark/cache-offloading/run.sh
}

wait_for_vllm() {
    echo "Waiting for vllm server to be ready..."
    for i in {1..120}; do
        sleep 5
        # 检查 completions 或 metrics 接口
        if curl --noproxy localhost,127.0.0.1 -s -o /dev/null -w "%{http_code}" \
            -H "Content-Type: application/json" \
            -d '{"model": "deepseek-ai/deepseek-r1-0528", "prompt": "Hello", "max_tokens": 1}' \
            http://localhost:8000/v1/completions | grep -q "200"; then
            echo "vllm /v1/completions is up."
            return 0
        fi
        if curl --noproxy localhost,127.0.0.1 -s -o /dev/null -w "%{http_code}" http://localhost:8000/metrics | grep -q "200"; then
            echo "vllm /metrics is up."
            return 0
        fi
    done
    echo "Timeout waiting for vllm server!"
    return 1
}

for idx in 0 1 2; do
    echo "=============================="
    echo "[Step $((idx+1))] Starting vllm server with config $((idx+1))..."
    # 停止并删除旧容器
    docker rm -f $CONTAINER_NAME || true
    # 启动新容器，直接运行 vllm serve 并保存日志
    docker run --entrypoint /bin/bash --network host --shm-size 10.24g --gpus all -d --name $CONTAINER_NAME -e VLLM_HOST_IP=$HOST_IP "${MOUNTS[@]}" $IMAGE -c "${CMDS[$idx]} > /tmp/vllm.log 2>&1"
    # 等待服务启动
    wait_for_vllm
    # 压测
    run_benchmark
    # 收集结果
    OUTDIR="results_config_$((idx+1))"
    mkdir -p $OUTDIR
    cp /root/daocloud/src/vllm-benchmark/compare_offloading.csv $OUTDIR/
    cp /root/daocloud/src/vllm-benchmark/cache-offloading/gpu_usage.log $OUTDIR/
    docker cp $CONTAINER_NAME:/tmp/vllm.log $OUTDIR/vllm.log
    echo "[Step $((idx+1))] Done. Results saved to $OUTDIR."
    # 停止容器
    docker rm -f $CONTAINER_NAME
    sleep 10
    echo "=============================="
done

echo "All benchmarks finished."
