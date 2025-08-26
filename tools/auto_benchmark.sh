#!/bin/bash
set -x
set -e

IMAGE="lmcache/vllm-openai:v0.3.3-gds"
BENCHMARK_IMAGE="vllm-benchmark:latest"
CONTAINER_NAME="vllm-server"
BENCHMARK_CONTAINER_NAME="vllm-benchmark"
HOST_IP="10.20.10.2"
MODEL_PATH="/models/DeepSeek-R1-0528"
TP_SIZE=8
CPU_CACHE=50

# 挂载参数
MOUNTS=(
    -v "/root/daocloud/lmcache:/config"
    -v "/root/daocloud/src:/src"
    -v "/mnt/data:/models"
    -v "/400Gb:/mnt/400gb"
    -v "/mnt/NVMe-oF800:/mnt/800gb"
)

VLLM_COMMON_ARGS="/opt/venv/bin/vllm serve $MODEL_PATH --served-model-name deepseek-ai/deepseek-r1-0528 --tensor-parallel-size $TP_SIZE --no-enable-prefix-caching --disable-log-requests"
LMCACHE_COMMON_ARGS="LMCACHE_USE_EXPERIMENTAL=True LMCACHE_CHUNK_SIZE=256 LMCACHE_MAX_LOCAL_CPU_SIZE=$CPU_CACHE"

# 启动命令数组
CMD5="$LMCACHE_COMMON_ARGS LMCACHE_CUFILE_BUFFER_SIZE="8192" LMCACHE_LOCAL_CPU=False LMCACHE_GDS_PATH=\"/mnt/400gb/cache/deepseek-r1-gds/\" LMCACHE_EXTRA_CONFIG='{\"create_lookup_server_only_on_worker_0\":true}' $VLLM_COMMON_ARGS --kv-transfer-config '{\"kv_connector\":\"LMCacheConnectorV1\", \"kv_role\":\"kv_both\"}'"
CMD6="$LMCACHE_COMMON_ARGS LMCACHE_CUFILE_BUFFER_SIZE="8192" LMCACHE_LOCAL_CPU=False LMCACHE_GDS_PATH=\"/mnt/800gb/cache/deepseek-r1-gds/\" LMCACHE_EXTRA_CONFIG='{\"create_lookup_server_only_on_worker_0\":true}' $VLLM_COMMON_ARGS --kv-transfer-config '{\"kv_connector\":\"LMCacheConnectorV1\", \"kv_role\":\"kv_both\"}'"
CMD1="$LMCACHE_COMMON_ARGS LMCACHE_LOCAL_DISK=\"file:///mnt/400gb/cache/deepseek-r1-file/\" LMCACHE_MAX_LOCAL_DISK_SIZE=5000.0 $VLLM_COMMON_ARGS --kv-transfer-config '{\"kv_connector\":\"LMCacheConnectorV1\", \"kv_role\":\"kv_both\"}'"
CMD2="$LMCACHE_COMMON_ARGS LMCACHE_LOCAL_DISK=\"file:///mnt/800gb/cache/deepseek-r1-file/\" LMCACHE_MAX_LOCAL_DISK_SIZE=5000.0 $VLLM_COMMON_ARGS --kv-transfer-config '{\"kv_connector\":\"LMCacheConnectorV1\", \"kv_role\":\"kv_both\"}'"
CMD3="$LMCACHE_COMMON_ARGS $VLLM_COMMON_ARGS --kv-transfer-config '{\"kv_connector\":\"LMCacheConnectorV1\", \"kv_role\":\"kv_both\"}'"
CMD4="$VLLM_COMMON_ARGS"

CMDS=("$CMD5" "$CMD6")
METADATAS=(
    "kvcache=gds-400g chunksize=256"
    "kvcache=gds-800g chunksize=256"
    "kvcache=disk-400g chunksize=256"
    "kvcache=disk-800g chunksize=256"
    "kvcache=cpu chunksize=256"
    "kvcache=none"
)
DATESTR=$(date +"%Y%m%d-%H%M%S")
OUTPUT_NAMES=(
    "ds-${DATESTR}-gds-400g"
    "ds-${DATESTR}-gds-800g"
    "ds-${DATESTR}-disk-400g"
    "ds-${DATESTR}-disk-800g"
    "ds-${DATESTR}-cpu"
    "ds-${DATESTR}-no-kvcache"
)

run_benchmark() {
    local metadata="$1"
    local out_dir="$2"
    echo "Running benchmark with metadata: $metadata and output to: $out_dir"
    mkdir -p "$out_dir"
    docker run \
        --entrypoint /bin/bash \
        --network host \
        --gpus all \
        -it \
        --rm \
        --name $BENCHMARK_CONTAINER_NAME \
        -e BENCHMARK_RESULTS_FILE=benchmark_result.json \
        -e OUTPUT_DIR=/out \
        -v "/mnt/data:/models" \
        -v "/root/daocloud/datasets:/datasets" \
        -v "/root/daocloud/src:/src" \
        -v "$out_dir:/out" \
        $BENCHMARK_IMAGE -c "bash /src/vllm-benchmark/cache-offloading/run.sh $metadata"
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

vllm_serve() {
    local cmd="$1"
    echo "Starting vllm server with command: $cmd"
    docker run \
        --entrypoint /bin/bash \
        --network host \
        --shm-size 10.24g \
        --gpus all \
        --rm \
        -d \
        --name $CONTAINER_NAME \
        -e VLLM_HOST_IP=$HOST_IP \
        "${MOUNTS[@]}" \
        $IMAGE -c "$cmd"
    wait_for_vllm
}

# 0. benckmark_results.json
# 1. vllm.log
# 2. gpu_usage.log
# 3. metrics.json
collect_results() {
    local outdir="$1"
    mkdir -p $outdir
    docker cp $CONTAINER_NAME:/tmp/vllm.log $outdir/vllm.log
}

remove_container() {
    local cname="$1"
    local max_retry=10
    local count=0
    while docker ps -a --format '{{.Names}}' | grep -wq "$cname"; do
        docker rm -f "$cname" || {
            echo "docker rm failed for $cname, trying docker kill...";
            docker kill "$cname" || true;
            sleep 2;
        }
        count=$((count+1))
        if [ $count -ge $max_retry ]; then
            echo "Failed to remove container $cname after $max_retry attempts."
            break
        fi
        sleep 2
    done
}

clean_cache() {
    echo "Cleaning up old containers..."
    remove_container "$CONTAINER_NAME"
    remove_container "$BENCHMARK_CONTAINER_NAME"
    echo "Cleaning up old results..."
    rm -rf /400Gb/cache/deepseek-r1-file/
    rm -rf /400Gb/cache/deepseek-r1-gds/
    mkdir -p /400Gb/cache/deepseek-r1-file/
    mkdir -p /400Gb/cache/deepseek-r1-gds/
    rm -rf /mnt/NVMe-oF800/cache/deepseek-r1-file/
    rm -rf /mnt/NVMe-oF800/cache/deepseek-r1-gds/
    mkdir -p /mnt/NVMe-oF800/cache/deepseek-r1-gds/
    mkdir -p /mnt/NVMe-oF800/cache/deepseek-r1-file/
}

clean_cache
for idx in 1 0; do
    echo "=============================="
    echo "[Step $((idx+1))] Starting vllm server with config $((idx+1))..."
    # 停止并删除旧容器
    #docker rm -f $CONTAINER_NAME || true
    # 启动新容器，直接运行 vllm serve 并保存日志
    vllm_serve "${CMDS[$idx]} > /tmp/vllm.log 2>&1"
    # 压测
    OUTDIR="${OUTPUT_NAMES[$idx]}"
    run_benchmark "${METADATAS[$idx]}" "$(pwd)/$OUTDIR"
    # 收集结果
    echo "[Step $((idx+1))] Done. Results saved to $OUTDIR."
    collect_results $OUTDIR
    # 停止容器
    remove_container "$CONTAINER_NAME"
    sleep 10
    echo "=============================="
done

echo "All benchmarks finished."