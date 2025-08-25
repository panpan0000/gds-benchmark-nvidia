#!/usr/bin/env python3
import os
import shutil
import subprocess
import re

old_name_prefix = 'ds-20250822-141013'
new_name_prefix = ''

def main():
    root = 'benchmark_result_0822_raw'
    out_dir = 'benchmark_result_0822'
    os.makedirs(out_dir, exist_ok=True)
    for sub in os.listdir(root):
        sub_path = os.path.join(root, sub)
        if not os.path.isdir(sub_path):
            continue
        # 直接用文件夹名后缀
        new_name = sub.replace(old_name_prefix, new_name_prefix)+".json"
        src_json = os.path.join(sub_path, 'benchmark_result.json')
        dst_json = os.path.join(out_dir, new_name)
        if os.path.exists(src_json):
            shutil.copy(src_json, dst_json)
            print(f'Copied {src_json} -> {dst_json}')
            # 调用 plot_benchmark.py 生成 png
            png_prefix = dst_json.replace('.json', '')
            subprocess.run(['python3', 'tools/plot_benchmark.py', dst_json, png_prefix])
            print(f'Generated {png_prefix}')

if __name__ == '__main__':
    main()
