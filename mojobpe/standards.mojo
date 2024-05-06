alias GPT2_SPLIT_PATTERN = r"""'(?:[sdmt]|ll|ve|re)| ?\p{L}+| ?\p{N}+| ?[^\s\p{L}\p{N}]+|\s+(?!\S)|\s+"""
alias GPT4_SPLIT_PATTERN = r"""'(?i:[sdmt]|ll|ve|re)|[^\r\n\p{L}\p{N}]?+\p{L}+|\p{N}{1,3}| ?[^\s\p{L}\p{N}]++[\r\n]*|\s*[\r\n]|\s+(?!\S)|\s+"""
alias GPT4_SPECIAL_TOKENS = "{'<|endoftext|>': 100257,'<|fim_prefix|>': 100258,'<|fim_middle|>': 100259,'<|fim_suffix|>': 100260,'<|endofprompt|>': 100276}"

