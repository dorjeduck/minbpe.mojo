# minbpe.🔥

This project is a port of Andrej Karpathy's [minbpe](https://github.com/karpathy/minbpe) to [Mojo](https://docs.modular.com/mojo), currently in alpha and actively developed. Not all features of Minpe are available yet, but they will be introduced as the project evolves.

## Implementation 

Due to differences in language capabilities, the architecture of the application has been modified to fit the constraints and features of Mojo. While the architecture is different, the core functionalities and behaviors of the application remain the same as in the original.

## Available Tokenizer

Tokenizers in `mojobpe` are implemented by confirming to the `TokenizationStrategy` trait, which defines the required methods and properties for tokenization processes. 

- **BasicTokenizationStrategy**: Implements the BasicTokenizer, the simplest implementation of the BPE algorithm that runs directly on text.
- **RegexTokenizationStrategy**: Implements the RegexTokenizer that further splits the input text by a regex pattern, which is a preprocessing stage that splits up the input text by categories.



## License

MIT
