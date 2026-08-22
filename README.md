# minbpe.🔥

This project is a port of Andrej Karpathy's [minbpe](https://github.com/karpathy/minbpe) to [Mojo](https://docs.modular.com/mojo), currently in beta.

`Minbpe` implements the Byte Pair Encoding (BPE) algorithm, which is commonly used in large language models (LLMs) tokenization. For a comprehensive explanation of this project, visit its GitHub page at [https://github.com/karpathy/minbpe](https://github.com/karpathy/minbpe). Not all features of `minpe` are available in this port.

> **Note**: This project is based on the stable Mojo 1.0 release.

## Implementation

Due to differences in language capabilities, the architecture of this port has been modified to fit the constraints and features of Mojo. While the architecture is different, the core functionalities and behaviors of the application remain the same as in the original. As Mojo's language features continue to evolve, we expect to further refine and redesign the project.

## Available Tokenizer

Tokenizers in `minbpe.mojo` are implemented by confirming to the `Tokenizer` trait, which defines the required methods around tokenization processes.

- **BasicTokenizer**: Implements the BasicTokenizer, the simplest implementation of the BPE algorithm that runs directly on text.
- **RegexTokenizer**: Implements the RegexTokenizer that further splits the input text by a regex pattern, which is a preprocessing stage that splits up the input text by categories (think: letters, numbers, punctuation) before tokenization. This ensures that no merges will happen across category boundaries. This was introduced in the GPT-2 paper and continues to be in use as of GPT-4. This class also handles special tokens, if any.
- **GPT4Tokenizer** to be implemented

## Quick Start

- If you don't have it, install [pixi](https://pixi.sh/latest/):
- Run `pixi shell` within the root of the cloned repository to install the project's dependencies (Mojo 1.0), and to activate the project's virtual environment in which you can run the mojo apps.

The [quick start](https://github.com/karpathy/minbpe?tab=readme-ov-file#quick-start) example from `minbpe` can be implement with `minbpe.mojo` as follows:

 ```python
from mojobpe import Tokenizer,BasicTokenizer
from mojobpe.utils.tat import print_list_int

def main() raises:
    var text = "aaabdaaabac"

    var tokenizer = BasicTokenizer()
    tokenizer.train(text, 256 + 3) # 256 are the byte tokens, then do 3 merges
    print_list_int(tokenizer.encode(text))
    # [258, 100, 258, 97, 99]

    print(tokenizer.decode([258, 100, 258, 97, 99]))
    # aaabdaaabac

    tokenizer.save("toy")
    # writes toy.model (for loading) 
```

## Benchmarks

See [benchmarks/benchmark.md](benchmarks/benchmark.md) for a comparison against Karpathy's Python `minbpe` and Gregor Purdy's Rust port.

## Training

`train.mojo` is a Mojo port of `train.py` from the original repository and writes the model files in `models/`:

```bash
pixi run train
```

## Tests

```bash
pixi run test
```

## Changelog

- 2026.08.22
  - Update to Mojo 1.0
  - Replaced the vendored `CompactDict` copy with the Mojo standard library's `Dict`, `Set` and `Counter`
  - Fixed a merge tie-break discrepancy: training output now matches the reference `minbpe` implementation exactly
  - Fixed UTF-8 decoding: the vocab now stores raw bytes, so multi-byte codepoints survive a decode round-trip
  - `train` now raises a descriptive error when `vocab_size` exceeds what the text supports, instead of failing with an out-of-bounds access
  - Added a test suite (`tests/test_minbpe.mojo`)
  - Fixed `load`: merges are now replayed into the vocab, so a loaded tokenizer can decode and not just encode
  - Added `benchmarks/`: the Mojo benchmark now averages 10 timed rounds after 2 warmup rounds on a fresh tokenizer per round, and the same workload runs against Karpathy's Python `minbpe` and Gregor Purdy's Rust port for a three-way comparison ([benchmarks/benchmark.md](benchmarks/benchmark.md))
- 2025.08.07
  - Update to Mojo 25.5
- 2024.10.09
  - Update to Mojo 24.5
- 2024.06.07
  - Update to Mojo 24.4
  - Performance improvements thanks to new features of [CompactDict](https://github.com/mzaks/compact-dict)
- 2024.05.14
  - Status: Beta
  - Performance improvements
- 2024.05.12
  - Switch to [MoString](https://github.com/dorjeduck/mostring) for String concatenation
- 2024.05.04
  - Initial repository setup and commit.

### Remarks

- Up to the Mojo 25.5 release this port relied on [Maxim Zaks'](https://github.com/mzaks) excellent [CompactDict](https://github.com/mzaks/compact-dict) library, a slightly modified copy of which lived in `mojobpe/utils` (`generic_dict` and `string_dict`); all credits go to him. With Mojo 1.0 the standard library's `Dict`, `Set` and `Counter` cover our needs, so the vendored copy has been retired.
- [Gregor Purdy](https://github.com/gnp) has implemented an impressive [Rust port](https://github.com/gnp/minbpe-rs) of `minbpe`, which `benchmarks/rs/` benchmarks alongside this one; see [benchmarks/benchmark.md](benchmarks/benchmark.md).

## License

MIT
