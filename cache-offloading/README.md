# Cache offloading benchmark

```bash
python3 benchmark/benchmark_serving.py \
  --backend openai \
  --model /models/deepseek-v3 \
  --endpoint http://localhost:8000/v1/completions \
  --dataset sharegpt_prompts.txt \
  --max-tokens 512 \
  --num-prompts 1000 \
  --num-concurrent-requests 10
  --save-results results.json
```

