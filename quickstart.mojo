from mojobpe import Tokenizer,BasicTokenizationStrategy
from mojobpe.utils.tat import print_list_int

fn main() raises:
    var text = "aaabdaaabac"

    var tokenizer = Tokenizer[BasicTokenizationStrategy]()
    tokenizer.train(text, 256 + 3) # 256 are the byte tokens, then do 3 merges
    print_list_int(tokenizer.encode(text))
    # [258, 100, 258, 97, 99]

    print(tokenizer.decode(List[Int](258, 100, 258, 97, 99)))
    # aaabdaaabac

    tokenizer.save("toy")
    # writes toy.model (for loading) 