from datasets import load_dataset


dataset = load_dataset("anon8231489123/ShareGPT_Vicuna_unfiltered")

# 保存到本地
dataset.save_to_disk("ShareGPT_Vicuna_unfiltered")

