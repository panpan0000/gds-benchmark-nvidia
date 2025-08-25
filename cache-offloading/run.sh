#!/bin/bash

DATESTR=$(date +"%Y%m%d-%H%M%S")
OUTPUT_DIR=${OUTPUT_DIR:-/datasets/benchmark_results}
BENCHMARK_RESULTS_FILE=${BENCHMARK_RESULTS_FILE:-${DATESTR}.json}
OUTPUT_LEN=${OUTPUT_LEN:-1}  # Default output length if not set
PROMPTS_NUM=${PROMPTS_NUM:-50}  # Number of prompts to use in the benchmark
SEED=$((RANDOM % 100))

# 解析命令行参数，合并为 metadata_extra
metadata_extra=""
for arg in "$@"; do
    if [[ "$arg" == *=* ]]; then
        metadata_extra+=" $arg"
    fi
    # 不处理非key=value参数
    shift
    # 只保留key=value参数
    # 其他参数可按需扩展
    # ...
done

run_benchmark() {
    python3 benchmarks/benchmark_serving.py \
        --model /models/DeepSeek-R1-0528 \
        --served-model-name deepseek-ai/deepseek-r1-0528 \
        --save-result \
        --save-detailed \
        --append-result \
        --result-filename "$OUTPUT_DIR/$BENCHMARK_RESULTS_FILE" \
        $@
}

run_random() {
    run_benchmark --dataset-name random \
        --seed $SEED \
        --num-prompts $PROMPTS_NUM \
        --max-concurrency 16 \
        $@
}

run_random_len() {
    local input_len=$1
    local iteration=${2:-1}
    run_random --random-input-len $input_len \
        --random-output-len $OUTPUT_LEN \
        --metadata "input_len=$input_len iteration=$iteration$metadata_extra"
}

warmup() {
    echo "Warming up the model..."
    run_benchmark --dataset-name random \
        --seed 2 \
        --num-prompts 5 \
        --max-concurrency 1 \
        --random-input-len 100 \
        --random-output-len 1 \
        --metadata "type=warmup"
}

repeatn() {
    local n=$1
    shift
    for i in $(seq 1 $n); do
        echo "Running command: $@ (iteration $i)"
        "$@" $i
        sleep 5  # sleep for 5 seconds between runs
    done
}

# 启动 GPU 利用率采集
nohup nvidia-smi --query-gpu=timestamp,index,name,utilization.gpu,utilization.memory,memory.used,memory.total --format=csv -l 1 > "$OUTPUT_DIR/gpu_usage.log" 2>&1 &

# run random for 100, 1k, 10k, 50k, 100k 3 times each
warmup
echo "Starting benchmark runs..."
for len in 100 1000 10000 50000 100000; do
    repeatn 3 run_random_len $len
    # 可根据需要调整采样次数
    # repeatn 5 run_random_len $len
    # sleep 10
    # ...
done

# 停止 GPU 利用率采集
pkill -f "nvidia-smi --query-gpu"
