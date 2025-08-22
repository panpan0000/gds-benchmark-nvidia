import json
import matplotlib.pyplot as plt

file_path = 'cache-offloading/deepseek-r1-0528-cache-offloading-20250821-235519.json'
metrics = ['total_token_throughput', 'mean_ttft_ms', 'mean_itl_ms']
input_lens = ["100", "1000", "10000", "50000", "100000"]
colors = ['r', 'g', 'b', 'c', 'm', 'y', 'k']

# 分组数据: {iteration: {input_len: {metrics}}}
data_dict = {}
with open(file_path, 'r') as f:
    for line in f:
        try:
            d = json.loads(line)
            if d.get('type') == 'warmup':
                continue
            input_len = d.get('input_len')
            iteration = d.get('iteration')
            if input_len in input_lens and iteration is not None:
                if iteration not in data_dict:
                    data_dict[iteration] = {}
                data_dict[iteration][input_len] = {m: d.get(m, 0) for m in metrics}
        except Exception:
            continue

x_pos = list(range(len(input_lens)))
x_labels = [str(l) for l in input_lens]
metric_names = {
    'total_token_throughput': 'Total Token Throughput',
    'mean_ttft_ms': 'Mean TTFT (ms)',
    'mean_itl_ms': 'Mean ITL (ms)'
}
file_names = {
    'total_token_throughput': 'benchmark_plot_throughput.png',
    'mean_ttft_ms': 'benchmark_plot_ttft.png',
    'mean_itl_ms': 'benchmark_plot_itl.png'
}
for m in metrics:
    plt.figure(figsize=(10,6))
    for idx, (iteration, input_dict) in enumerate(sorted(data_dict.items())):
        y = [input_dict.get(l, {}).get(m, 0) for l in input_lens]
        plt.plot(x_pos, y, color=colors[idx % len(colors)], marker='o', label=f'iteration {iteration}')
        for xi, yi in zip(x_pos, y):
            plt.annotate(f'{yi:.2f}', (xi, yi), textcoords="offset points", xytext=(0,10), ha='center', fontsize=8)
    plt.xlabel('Input Length')
    ylabel = metric_names[m]
    plt.ylabel(ylabel)
    plt.title(f'{metric_names[m]} by Iteration and Input Length')
    plt.xticks(x_pos, x_labels)
    plt.yscale('log')
    plt.legend()
    plt.tight_layout()
    plt.savefig(file_names[m])
    plt.close()