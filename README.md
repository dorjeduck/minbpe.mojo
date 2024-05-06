# minbpe.🔥

This project is a port of Andrej Karpathy's [minbpe](https://github.com/karpathy/minbpe) to [Mojo](https://docs.modular.com/mojo), currently in alpha and actively developed. Not all features of `minpe` are available yet, but they will be introduced as the project evolves.

## Implementation 

Due to differences in language capabilities, the architecture of the application has been modified to fit the constraints and features of Mojo. While the architecture is different, the core functionalities and behaviors of the application remain the same as in the original.

## Available Tokenizer

Tokenizers in `mojobpe` are implemented by confirming to the `TokenizationStrategy` trait, which defines the required methods around tokenization processes.

- **BasicTokenizationStrategy**: Implements the BasicTokenizer, the simplest implementation of the BPE algorithm that runs directly on text.
- **RegexTokenizationStrategy**: Implements the RegexTokenizer that further splits the input text by a regex pattern, which is a preprocessing stage that splits up the input text by categories.
- **GPT4TokenizationStrategy** coming soon

## Quick Start
 
 Start by installing the Python library `regex`. We rely on `regex` because Mojo currently lacks a powerful native regular expression library. Mojo's ability to utilize Python libraries allows us to enhance functionality in this way.

 ```bash
 pip install regex
 ```

 The quick start example from `minbpe` can be implement with minbpe.mojo as follows:

 ```python
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
```

## Benchmarks 

coming soon

### Remarks
- We included a Mojo port of `train.py` from the orignial repo which measures the time for training both the Basic and Regex Tokenizer with the text from Taylor Swift's wikipedia page. In our first tests, our Mojo version is around 3 times faster that then the python original.
- We achieved big performace boost by utlizings [Maxim Zaks](https://github.com/mzaks) excellent Mojo libraray [CompactDict](https://github.com/mzaks/compact-dict), which offers blazing fast dictionary implementations in Mojo. As we use a slightly modified version of it we include the lib in `mojobe.utils` folder, yet all credits to him. 
- [Gregor Purdy](https://github.com/gnp) has implement an excellent Rust port of `minbpe` In our first tests, Gergor's port is slightly faster than our current Mojo port. We are looking forward to give detailed performance comparison between the orignal and the two available ports. This is of course not about who is fastest but how to inspire each other to build excellent, performand open source projects.  

## License

MIT
