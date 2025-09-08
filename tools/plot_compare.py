import sys
import json
import matplotlib.pyplot as plt

# 用法: python plot_compare.py <metric> <json1> <json2> ...
if len(sys.argv) < 3:
    print("Usage: python plot_compare.py <metric> <json1> <json2> ...")
    sys.exit(1)

metric = sys.argv[1]
json_files = sys.argv[2:]
input_lens = ["100", "1000", "10000", "50000", "100000"]
x_pos = list(range(len(input_lens)))
x_labels = [str(l) for l in input_lens]

plt.figure(figsize=(10,6))
for file_path in json_files:
    with open(file_path, 'r') as f:
        y = []
        date = None
        kvcache = None
        for line in f:
            try:
                d = json.loads(line)
                if d.get('type') == 'warmup':
                    continue
                if d.get('iteration') != "3":
                    continue
                if date is None:
                    date = d.get('date', '')
                if kvcache is None:
                    kvcache = d.get('kvcache', '')
                input_len = d.get('input_len')
                if input_len in input_lens:
                    y.append(d.get(metric, 0))
            except Exception:
                continue
        # 补齐长度
        if len(y) < len(input_lens):
            y += [0] * (len(input_lens) - len(y))
        label = f"{date} {kvcache}"
        plt.plot(x_pos, y, marker='o', label=label)
        # 标注具体的值
        for xi, yi in zip(x_pos, y):
            plt.text(xi, yi, f"{yi:.2f}", ha='center', va='bottom', fontsize=9)

plt.xlabel('Input Length')
plt.ylabel(metric)
plt.title(f'Comparison of {metric} (iteration=3)')
plt.xticks(x_pos, x_labels)
plt.yscale('log')
plt.legend()
plt.tight_layout()
plt.savefig(f'compare_{metric}.png')
plt.close()
print(f"Saved compare_{metric}.png")