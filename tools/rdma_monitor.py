#!/usr/bin/env python3
"""
InfiniBand 网络监控工具
监控 InfiniBand 设备的发送和接收数据速率
"""

import os
import time
import glob
import signal
import sys
from datetime import datetime
from typing import Dict, Tuple


class InfiniBandMonitor:
    def __init__(self):
        self.previous_xmit = {}
        self.previous_rcv = {}
        self.ib_base_path = "/sys/class/infiniband"
        
    def check_infiniband_support(self) -> bool:
        """检查系统是否支持 InfiniBand"""
        if not os.path.exists(self.ib_base_path):
            print(f"错误: {self.ib_base_path} 目录不存在")
            print("请确认系统是否启用了 InfiniBand 支持")
            return False
        
        # 检查是否有 InfiniBand 设备
        devices = glob.glob(f"{self.ib_base_path}/*/ports/1/counters/port_xmit_data")
        if not devices:
            print("错误: 未找到 InfiniBand 设备")
            return False
            
        return True
    
    def format_bytes(self, bytes_value: int) -> str:
        """将字节数格式化为人类可读的单位"""
        if bytes_value == 0:
            return "0 B/s"
            
        units = ["B/s", "KB/s", "MB/s", "GB/s", "TB/s", "PB/s"]
        unit_index = 0
        value = float(bytes_value)
        
        while value >= 1024 and unit_index < len(units) - 1:
            value /= 1024
            unit_index += 1
        
        # 根据数值大小决定小数位数
        if value >= 100:
            return f"{value:.0f} {units[unit_index]}"
        elif value >= 10:
            return f"{value:.1f} {units[unit_index]}"
        else:
            return f"{value:.2f} {units[unit_index]}"
    
    def get_device_name(self, counter_path: str) -> str:
        """从计数器路径中提取设备名称"""
        return counter_path.split('/')[-5]
    
    def read_counter(self, counter_path: str) -> int:
        """读取计数器值并转换为实际字节数"""
        try:
            with open(counter_path, 'r') as f:
                counter_value = int(f.read().strip())
                # InfiniBand 计数器以4字节为单位，需要乘以4得到实际字节数
                return counter_value * 4
        except (IOError, ValueError) as e:
            print(f"警告: 无法读取 {counter_path}: {e}")
            return 0
    
    def get_current_counters(self) -> Tuple[Dict[str, int], Dict[str, int]]:
        """获取当前所有设备的计数器值"""
        current_xmit = {}
        current_rcv = {}
        
        # 读取发送计数器
        xmit_paths = glob.glob(f"{self.ib_base_path}/*/ports/1/counters/port_xmit_data")
        for path in xmit_paths:
            device_name = self.get_device_name(path)
            current_xmit[device_name] = self.read_counter(path)
        
        # 读取接收计数器
        rcv_paths = glob.glob(f"{self.ib_base_path}/*/ports/1/counters/port_rcv_data")
        for path in rcv_paths:
            device_name = self.get_device_name(path)
            current_rcv[device_name] = self.read_counter(path)
        
        return current_xmit, current_rcv
    
    def initialize_counters(self):
        """初始化计数器值"""
        self.previous_xmit, self.previous_rcv = self.get_current_counters()
        print(f"发现 {len(self.previous_xmit)} 个 InfiniBand 设备")
        for device in self.previous_xmit.keys():
            print(f"  - {device}")
        print()
    
    def display_header(self):
        """显示表头"""
        print(f"最后更新: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print()
        print(f"{'设备名称':<15} {'TX Gbps':<15} {'RX Gbps':<15}")
        print("=" * 50)
    
    def display_rates(self, device_name: str, xmit_diff: int, rcv_diff: int):
        """显示单个设备的速率信息"""
        # 计算 Gbps（千兆位每秒）
        tx_gbps = (xmit_diff * 8) / (1000**3)  # 转换为Gbps (1000进制)
        rx_gbps = (rcv_diff * 8) / (1000**3)
        
        # 添加颜色编码（如果速率很高）
        tx_color = ""
        rx_color = ""
        reset_color = ""
        
        # 如果在支持颜色的终端中运行
        if hasattr(sys.stdout, 'isatty') and sys.stdout.isatty():
            if tx_gbps > 100:  # > 100 Gbps
                tx_color = "\033[91m"  # 红色
                reset_color = "\033[0m"
            elif tx_gbps > 10:  # > 10 Gbps
                tx_color = "\033[93m"  # 黄色
                reset_color = "\033[0m"
            
            if rx_gbps > 100:  # > 100 Gbps
                rx_color = "\033[91m"  # 红色
                reset_color = "\033[0m"
            elif rx_gbps > 10:  # > 10 Gbps
                rx_color = "\033[93m"  # 黄色
                reset_color = "\033[0m"
        
        print(f"{device_name:<15} "
              f"{tx_color}{tx_gbps:>10.1f} Gbps{reset_color} "
              f"{rx_color}{rx_gbps:>10.1f} Gbps{reset_color}")
    
    def signal_handler(self, signum, frame):
        """处理中断信号"""
        print("\n\n程序被用户中断")
        print("感谢使用 InfiniBand 监控工具！")
        sys.exit(0)
    
    def run(self):
        """主监控循环"""
        # 检查 InfiniBand 支持
        if not self.check_infiniband_support():
            sys.exit(1)
        
        # 设置信号处理器
        signal.signal(signal.SIGINT, self.signal_handler)
        
        print("InfiniBand 网络监控工具")
        print("按 Ctrl+C 停止监控")
        print("=" * 50)
        
        # 初始化计数器
        self.initialize_counters()
        
        if not self.previous_xmit:
            print("错误: 没有找到可用的 InfiniBand 设备")
            sys.exit(1)
        
        try:
            while True:
                time.sleep(1)
                
                # 清屏
                os.system('clear' if os.name == 'posix' else 'cls')
                
                # 显示表头
                self.display_header()
                
                # 获取当前计数器值
                current_xmit, current_rcv = self.get_current_counters()
                
                # 计算并显示每个设备的速率
                total_tx = 0
                total_rx = 0
                
                for device_name in sorted(self.previous_xmit.keys()):
                    # 计算差值
                    xmit_diff = current_xmit.get(device_name, 0) - self.previous_xmit.get(device_name, 0)
                    rcv_diff = current_rcv.get(device_name, 0) - self.previous_rcv.get(device_name, 0)
                    
                    # 处理计数器重置的情况
                    if xmit_diff < 0:
                        xmit_diff = current_xmit.get(device_name, 0)
                    if rcv_diff < 0:
                        rcv_diff = current_rcv.get(device_name, 0)
                    
                    total_tx += xmit_diff
                    total_rx += rcv_diff
                    
                    self.display_rates(device_name, xmit_diff, rcv_diff)
                
                # 显示总计
                if len(self.previous_xmit) > 1:
                    total_tx_gbps = (total_tx * 8) / (1000**3)
                    total_rx_gbps = (total_rx * 8) / (1000**3)
                    print("-" * 50)
                    print(f"{'总计':<15} "
                          f"{total_tx_gbps:>10.1f} Gbps "
                          f"{total_rx_gbps:>10.1f} Gbps")
                
                print()
                print("说明:")
                print("  - 数值单位为 Gbps (千兆位每秒)")
                print("  - 使用十进制前缀 (1000进制，与网络标准一致)")
                print("  - 颜色编码: 黄色 >10Gbps, 红色 >100Gbps")
                
                # 更新上一次的值
                self.previous_xmit = current_xmit.copy()
                self.previous_rcv = current_rcv.copy()
                
        except KeyboardInterrupt:
            self.signal_handler(None, None)


def main():
    """主函数"""
    monitor = InfiniBandMonitor()
    monitor.run()


if __name__ == "__main__":
    main()