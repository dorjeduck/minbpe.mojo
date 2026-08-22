"""Reference benchmark: Karpathy's Python minbpe on the same workload.

Mirrors benchmark.mojo exactly -- same corpus, same 512 vocab, same warmup and
round counts, same per-phase timing -- so results_python.json and
results_mojo.json can be compared directly.

minbpe has no packaging metadata upstream, so it cannot be pip-installed. This
script looks for it in order: already importable, $MINBPE_PATH, then a
<repo>/.reference/minbpe checkout. Run `pixi run -e bench setup-reference` to
create one.
"""

import json
import os
import sys
import time

# Anchor paths to this source file rather than the working directory, so the
# benchmark can be run from anywhere.
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CORPUS = os.path.join(REPO_ROOT, "tests", "taylorswift.txt")
RESULTS = os.path.join(REPO_ROOT, "benchmarks", "results", "python.json")

TEST_ROUNDS = 10
WARMUP_ROUNDS = 2
VOCAB_SIZE = 512


def import_minbpe():
    candidates = []
    if os.environ.get("MINBPE_PATH"):
        candidates.append(os.environ["MINBPE_PATH"])
    candidates.append(os.path.join(REPO_ROOT, ".reference", "minbpe"))

    for path in candidates:
        if os.path.isdir(os.path.join(path, "minbpe")):
            sys.path.insert(0, path)
            break
    try:
        from minbpe import BasicTokenizer, RegexTokenizer
    except ImportError:
        sys.exit(
            "minbpe not found. Run `pixi run -e bench setup-reference` to clone\n"
            "it into <repo>/.reference, or point MINBPE_PATH at a checkout."
        )
    return BasicTokenizer, RegexTokenizer


def benchmark(cls, text, warmup_rounds, test_rounds):
    """Time train/encode/decode, averaged over `test_rounds` timed rounds.

    Every training round runs on a freshly constructed tokenizer, matching
    benchmark.mojo: `train` accumulates merges rather than replacing them, so
    reusing one tokenizer would skew both training and encoding. Construction
    sits outside the timed region.
    """
    for _ in range(warmup_rounds):
        tokenizer = cls()
        tokenizer.train(text, VOCAB_SIZE)
        tokenizer.decode(tokenizer.encode(text))

    t1 = 0
    for _ in range(test_rounds):
        tokenizer = cls()
        s1 = time.perf_counter_ns()
        tokenizer.train(text, VOCAB_SIZE)
        t1 += time.perf_counter_ns() - s1

    t2 = 0
    for _ in range(test_rounds):
        s2 = time.perf_counter_ns()
        encoded = tokenizer.encode(text)
        t2 += time.perf_counter_ns() - s2

    t3 = 0
    for _ in range(test_rounds):
        s3 = time.perf_counter_ns()
        tokenizer.decode(encoded)
        t3 += time.perf_counter_ns() - s3

    return [t1 / test_rounds, t2 / test_rounds, t3 / test_rounds]


def print_result(name, r):
    print("-------------------------------------------------------------")
    print("Benchmark results for", name, "\n")
    print(f"Average training time: {r[0] / 1_000_000_000} seconds")
    print(f"Average encoding time: {r[1] / 1_000_000_000} seconds")
    print(f"Average decoding time: {r[2] / 1_000_000_000} seconds\n")
    print(f"Sum: {sum(r) / 1_000_000_000} seconds")
    print("-------------------------------------------------------------")


def write_json(r1, r2):
    def block(data):
        return {
            "training_time": data[0] / 1_000_000_000,
            "encoding_time": data[1] / 1_000_000_000,
            "decoding_time": data[2] / 1_000_000_000,
            "total_time": sum(data) / 1_000_000_000,
        }

    results = {
        "basic": block(r1),
        "regex": block(r2),
        "overall_total_time": (sum(r1) + sum(r2)) / 1_000_000_000,
    }
    with open(RESULTS, "w") as f:
        json.dump(results, f, indent="\t")


def main():
    BasicTokenizer, RegexTokenizer = import_minbpe()

    with open(CORPUS, encoding="utf-8") as f:
        text = f.read()

    print(
        f"Benchmarking: {TEST_ROUNDS} timed rounds after "
        f"{WARMUP_ROUNDS} warmup rounds\n"
    )

    r1 = benchmark(BasicTokenizer, text, WARMUP_ROUNDS, TEST_ROUNDS)
    print_result("Basic Tokenizer", r1)

    r2 = benchmark(RegexTokenizer, text, WARMUP_ROUNDS, TEST_ROUNDS)
    print_result("Regex Tokenizer", r2)

    print(f"\nTotal average time: {(sum(r1) + sum(r2)) / 1_000_000_000} seconds\n")

    write_json(r1, r2)


if __name__ == "__main__":
    main()
