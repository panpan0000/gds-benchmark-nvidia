#!/usr/bin/env python3
import json
import os
import pandas as pd

def load_json_lines(filepath):
    rows = []
    with open(filepath, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('//'): continue
            try:
                row = json.loads(line)
                rows.append(row)
            except Exception:
                continue
    return rows

def extract_row(row, filename):
    if row.get('type', None) == 'warmup':
        return None
    return {
        'iteration': row.get('iteration', ''),
        'input_len': row.get('input_len', ''),
        'kvcache': row.get('kvcache', ''),
        'bandwidth': row.get('bandwidth', '') if 'bandwidth' in row else ('cpu' if row.get('kvcache', '') == 'cpu' else ''),
        'mean_ttft_ms': row.get('mean_ttft_ms', ''),
        'std_ttft_ms': row.get('std_ttft_ms', ''),
        'total_token_throughput': row.get('total_token_throughput', ''),
    }

def main():
    files = [
        'ds-0821-cpu-offloading.json',
        'ds-0821-400g-disk-offloading.json',
        'ds-0821-800g-disk-offloading.json',
    ]
    base_dir = os.path.dirname(__file__)
    all_rows = []
    for fname in files:
        fpath = os.path.join(base_dir, 'cache-offloading', fname)
        if not os.path.exists(fpath):
            print(f"File not found: {fpath}")
            continue
        for row in load_json_lines(fpath):
            extracted = extract_row(row, fname)
            if extracted:
                all_rows.append(extracted)
    df = pd.DataFrame(all_rows)
    # 拼接 kvcache 和 bandwidth
    df['cache_type'] = df['kvcache'].astype(str) + '-' + df['bandwidth'].astype(str)
    # 只保留需要的列
    df = df[['iteration', 'input_len', 'cache_type', 'mean_ttft_ms', 'std_ttft_ms', 'total_token_throughput']]
    print(df.to_string(index=False))
    df.to_csv(os.path.join(base_dir, 'compare_offloading.csv'), index=False)

if __name__ == '__main__':
    main()
