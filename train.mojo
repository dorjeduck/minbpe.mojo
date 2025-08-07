from time import perf_counter_ns as now

from mojobpe import BasicTokenizer, RegexTokenizer
from mojobpe.standards import GPT4_SPLIT_PATTERN, GPT4_SPECIAL_TOKENS
from mojobpe.utils.tat import print_list_int


fn main() raises:
    var text = open("tests/taylorswift.txt", "r").read()
    var vocab_size = 512

    var start = now()

    var tokenizer = BasicTokenizer()
    tokenizer.train(text, 512, True)
    tokenizer.save("models/basic")

    var tokenizer2 = RegexTokenizer[GPT4_SPLIT_PATTERN]()
    tokenizer2.register_special_tokens(GPT4_SPECIAL_TOKENS)
    tokenizer2.train(text, 512, True)
    tokenizer2.save("models/regex")

    var elapsed = now() - start

    var r = tokenizer.encode(text)

    print("Training took " + String(elapsed / 1_000_000_000) + " seconds")
