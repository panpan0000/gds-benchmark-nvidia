#!/bin/bash
# filepath: /home/yang/workspace/drun/vllm-benchmark/cache-offloading/benchmark.sh

# Define variables
MODEL_ENDPOINT="http://localhost:8000/v1/chat/completions"  # Default endpoint, can be overridden
OUTPUT_DIR="./benchmark_results"
DATASETS_DIR="./datasets"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RESULT_FILE="${OUTPUT_DIR}/benchmark_results_${TIMESTAMP}.json"

# Create output directory if it doesn't exist
mkdir -p $OUTPUT_DIR
mkdir -p $DATASETS_DIR

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --endpoint)
      MODEL_ENDPOINT="$2"
      shift 2
      ;;
    --output)
      OUTPUT_DIR="$2"
      RESULT_FILE="${OUTPUT_DIR}/benchmark_results_${TIMESTAMP}.json"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

echo "Model endpoint: $MODEL_ENDPOINT"
echo "Results will be saved to: $RESULT_FILE"

# Check if curl and jq are installed
if ! command -v curl &> /dev/null; then
    echo "Error: curl is not installed"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed"
    exit 1
fi

# Initialize result JSON
echo "{}" > $RESULT_FILE

# Function to run benchmark for a specific dataset
run_benchmark() {
  local dataset_name=$1
  local dataset_file=$2
  local num_samples=${3:-10}  # Default to 10 samples if not specified
  
  echo "Running benchmark for $dataset_name dataset..."
  
  # Check if dataset file exists
  if [ ! -f "$dataset_file" ]; then
    echo "Dataset file $dataset_file not found, skipping..."
    jq --arg name "$dataset_name" '. + {($name): {"error": "Dataset file not found"}}' $RESULT_FILE > tmp.$$.json && mv tmp.$$.json $RESULT_FILE
    return
  fi
  
  # Initialize metrics
  local total_time=0
  local total_tokens=0
  local requests_completed=0
  local start_time_global=$(date +%s.%N)
  
  # Create a temporary file for individual results
  local tmp_results=$(mktemp)
  echo "[]" > $tmp_results
  
  # Read samples from the dataset file (assuming JSON format)
  for i in $(seq 1 $num_samples); do
    if [ $i -gt $(jq '. | length' $dataset_file) ]; then
      break
    fi
    
    local prompt=$(jq -r ".[$i-1].prompt" $dataset_file)
    if [ "$prompt" == "null" ]; then
      # Try different JSON structure
      prompt=$(jq -r ".[$i-1].messages[0].content" $dataset_file 2>/dev/null)
    fi
    
    if [ -z "$prompt" ] || [ "$prompt" == "null" ]; then
      echo "Could not extract prompt from dataset, skipping sample $i"
      continue
    fi
    
    echo "Processing sample $i..."
    
    # Format the request payload
    local payload=$(cat << EOF
{
  "model": "default",
  "messages": [
    {
      "role": "user",
      "content": "$prompt"
    }
  ],
  "temperature": 0.7
}
EOF
)
    
    # Send request and measure performance
    local start_time=$(date +%s.%N)
    local response=$(curl -s -X POST "$MODEL_ENDPOINT" \
      -H "Content-Type: application/json" \
      -d "$payload")
    local end_time=$(date +%s.%N)
    local elapsed_time=$(echo "$end_time - $start_time" | bc)
    
    # Extract completion tokens
    local completion=$(echo $response | jq -r '.choices[0].message.content')
    local completion_tokens=$(echo $response | jq -r '.usage.completion_tokens')
    local prompt_tokens=$(echo $response | jq -r '.usage.prompt_tokens')
    
    if [ "$completion" == "null" ] || [ -z "$completion" ]; then
      echo "Error in API response: $response"
      continue
    fi
    
    # Update metrics
    total_time=$(echo "$total_time + $elapsed_time" | bc)
    total_tokens=$(echo "$total_tokens + $completion_tokens" | bc)
    requests_completed=$((requests_completed + 1))
    
    # Save individual result
    local sample_result=$(cat << EOF
{
  "sample_id": $i,
  "prompt_length": ${#prompt},
  "prompt_tokens": $prompt_tokens,
  "completion_length": ${#completion},
  "completion_tokens": $completion_tokens,
  "latency_seconds": $elapsed_time
}
EOF
)
    
    jq --argjson result "$sample_result" '. += [$result]' $tmp_results > tmp.$$.json && mv tmp.$$.json $tmp_results
  done
  
  local end_time_global=$(date +%s.%N)
  local total_elapsed=$(echo "$end_time_global - $start_time_global" | bc)
  
  # Calculate aggregate metrics
  local avg_latency=0
  local avg_tokens_per_sec=0
  
  if [ $requests_completed -gt 0 ]; then
    avg_latency=$(echo "scale=2; $total_time / $requests_completed" | bc)
    avg_tokens_per_sec=$(echo "scale=2; $total_tokens / $total_time" | bc)
  fi
  
  # Add dataset results to the main result file
  local dataset_results=$(cat << EOF
{
  "total_samples": $requests_completed,
  "total_time_seconds": $total_elapsed,
  "avg_latency_seconds": $avg_latency,
  "total_tokens_generated": $total_tokens,
  "tokens_per_second": $avg_tokens_per_sec,
  "samples": $(cat $tmp_results)
}
EOF
)
  
  jq --arg name "$dataset_name" --argjson results "$dataset_results" '. + {($name): $results}' $RESULT_FILE > tmp.$$.json && mv tmp.$$.json $RESULT_FILE
  
  # Clean up
  rm $tmp_results
  
  echo "Benchmark for $dataset_name completed."
}

# Download datasets if they don't exist
# ShareGPT dataset
if [ ! -f "${DATASETS_DIR}/sharegpt_sample.json" ]; then
  echo "Downloading ShareGPT sample dataset..."
  curl -s -o "${DATASETS_DIR}/sharegpt_sample.json" "https://huggingface.co/datasets/anon8231489123/ShareGPT_Vicuna_unfiltered/resolve/main/HTML_cleaned_raw_dataset.json?download=true" || \
  echo "[]" > "${DATASETS_DIR}/sharegpt_sample.json"
  # Take first 50 samples
  jq '.[0:50]' "${DATASETS_DIR}/sharegpt_sample.json" > tmp.$$.json && mv tmp.$$.json "${DATASETS_DIR}/sharegpt_sample.json"
fi

# Multi-turn QA dataset
if [ ! -f "${DATASETS_DIR}/multiturn_qa_sample.json" ]; then
  echo "Creating multi-turn QA sample dataset..."
  cat << 'EOF' > "${DATASETS_DIR}/multiturn_qa_sample.json"
[
  {
    "messages": [
      {"role": "user", "content": "What is machine learning?"}
    ]
  },
  {
    "messages": [
      {"role": "user", "content": "What is machine learning?"},
      {"role": "assistant", "content": "Machine learning is a subset of artificial intelligence that focuses on developing systems that can learn from and make decisions based on data."},
      {"role": "user", "content": "What are the main types of machine learning?"}
    ]
  },
  {
    "messages": [
      {"role": "user", "content": "What is machine learning?"},
      {"role": "assistant", "content": "Machine learning is a subset of artificial intelligence that focuses on developing systems that can learn from and make decisions based on data."},
      {"role": "user", "content": "What are the main types of machine learning?"},
      {"role": "assistant", "content": "The main types of machine learning are supervised learning, unsupervised learning, semi-supervised learning, and reinforcement learning."},
      {"role": "user", "content": "Can you explain supervised learning in more detail?"}
    ]
  }
]
EOF
fi

# Long context dataset
if [ ! -f "${DATASETS_DIR}/long_context_sample.json" ]; then
  echo "Creating long context sample dataset..."
  cat << 'EOF' > "${DATASETS_DIR}/long_context_sample.json"
[
  {
    "prompt": "Summarize the following text in 3-5 sentences: Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."
  },
  {
    "prompt": "Summarize the following document: Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."
  }
]
EOF

  # Generate longer contexts by repeating the lorem ipsum text
  python3 -c '
import json
import random

# Load the existing sample
with open("./datasets/long_context_sample.json", "r") as f:
    samples = json.load(f)

# Base lorem ipsum paragraph
lorem = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum. "

# Create samples with increasing context length
for i in range(3, 10):
    # Multiply the lorem ipsum text to create longer contexts
    repetitions = 2**i
    long_text = lorem * repetitions
    
    # Add a sample with the long context
    samples.append({
        "prompt": f"Summarize the following text in 5 sentences: {long_text}"
    })

# Write back to file
with open("./datasets/long_context_sample.json", "w") as f:
    json.dump(samples, f, indent=2)
' 2>/dev/null || echo "Could not generate longer contexts, using basic samples"
fi

# Run benchmarks for each dataset
run_benchmark "sharegpt" "${DATASETS_DIR}/sharegpt_sample.json" 10
run_benchmark "multiturn_qa" "${DATASETS_DIR}/multiturn_qa_sample.json" 10
run_benchmark "long_context" "${DATASETS_DIR}/long_context_sample.json" 10

# Add overall summary to results
jq '. + {"summary": {"timestamp": "'$(date -Iseconds)'", "datasets_tested": ["sharegpt", "multiturn_qa", "long_context"], "endpoint": "'$MODEL_ENDPOINT'"}}' $RESULT_FILE > tmp.$$.json && mv tmp.$$.json $RESULT_FILE

echo "Benchmark completed! Results saved to: $RESULT_FILE"
echo "Summary:"
jq '.summary' $RESULT_FILE

# Optional: Display a brief comparative analysis
echo "Comparative Analysis:"
echo "Average latency (seconds):"
jq -r '"\tShareGPT: \(.sharegpt.avg_latency_seconds // "N/A")\n\tMulti-turn QA: \(.multiturn_qa.avg_latency_seconds // "N/A")\n\tLong Context: \(.long_context.avg_latency_seconds // "N/A")"' $RESULT_FILE

echo "Tokens per second:"
jq -r '"\tShareGPT: \(.sharegpt.tokens_per_second // "N/A")\n\tMulti-turn QA: \(.multiturn_qa.tokens_per_second // "N/A")\n\tLong Context: \(.long_context.tokens_per_second // "N/A")"' $RESULT_FILE