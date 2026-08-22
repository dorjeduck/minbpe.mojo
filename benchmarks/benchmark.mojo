from std.os.path import dirname
from std.reflection import source_location
from std.time import perf_counter_ns as now

from mojobpe import Tokenizer, BasicTokenizer, RegexTokenizer
from mojobpe.standards import GPT4_SPLIT_PATTERN, GPT4_SPECIAL_TOKENS
from mojobpe.utils.tat import print_list_int

comptime TEST_ROUNDS = 10
comptime WARMUP_ROUNDS = 2
comptime VERBOSE = False


def benchmark[
    TK: Tokenizer & Movable & Deinitable
](text: String, warmup_rounds: Int, test_rounds: Int) raises -> List[Float64]:
    """Time train/encode/decode, averaged over `test_rounds` timed rounds.

    Every training round runs on a freshly constructed tokenizer: `train`
    appends to the merge rules rather than replacing them, so reusing one
    tokenizer would accumulate 256 extra rules per round and inflate both the
    training and the encoding times. Construction sits outside the timed
    region.
    """
    var tokenizer = TK()

    for _ in range(warmup_rounds):
        tokenizer = TK()
        tokenizer.train(text, 512, VERBOSE)
        var warm = tokenizer.encode(text)
        _ = tokenizer.decode(warm)

    var t1 = 0
    for _ in range(test_rounds):
        tokenizer = TK()
        var s1 = now()
        tokenizer.train(text, 512, VERBOSE)
        t1 += Int(now() - s1)

    var encoded = List[Int]()
    var t2 = 0
    for _ in range(test_rounds):
        var s2 = now()
        encoded = tokenizer.encode(text)
        t2 += Int(now() - s2)

    var decoded = String("")
    var t3 = 0
    for _ in range(test_rounds):
        var s3 = now()
        decoded = tokenizer.decode(encoded)
        t3 += Int(now() - s3)

    _ = decoded

    return [
        Float64(t1) / Float64(test_rounds),
        Float64(t2) / Float64(test_rounds),
        Float64(t3) / Float64(test_rounds),
    ]


def print_result(name: String, r: List[Float64]):
    print("-------------------------------------------------------------")
    print("Benchmark results for", name, "\n")
    print("Average training time: " + String(r[0] / 1_000_000_000) + " seconds")
    print("Average encoding time: " + String(r[1] / 1_000_000_000) + " seconds")
    print(
        "Average decoding time: " + String(r[2] / 1_000_000_000) + " seconds\n"
    )
    print("Sum: " + String((r[0] + r[1] + r[2]) / 1_000_000_000) + " seconds")
    print("-------------------------------------------------------------")


def json_block(name: String, data: List[Float64]) -> String:
    var total = (data[0] + data[1] + data[2]) / 1_000_000_000
    var res: String = ""
    res += '\t"' + name + '": {\n'
    res += '\t\t"training_time": ' + String(data[0] / 1_000_000_000) + ",\n"
    res += '\t\t"encoding_time": ' + String(data[1] / 1_000_000_000) + ",\n"
    res += '\t\t"decoding_time": ' + String(data[2] / 1_000_000_000) + ",\n"
    res += '\t\t"total_time": ' + String(total) + "\n"
    res += "\t},\n"
    return res


def repo_root() -> String:
    """Directory of this source file's parent, so paths do not depend on cwd.

    `source_location` only resolves inside a function body, and reports the
    path as it was given to the compiler. A shallow relative invocation such as
    `mojo run benchmarks/benchmark.mojo` therefore leaves nothing above
    `benchmarks/` -- in that case the working directory is already the root.
    """
    var src_dir = dirname(source_location().file_name())
    var root = dirname(src_dir)
    return root if root.byte_length() > 0 else String(".")


def write_json(
    results_path: String, r1: List[Float64], r2: List[Float64]
) raises:
    var ott = (r1[0] + r1[1] + r1[2] + r2[0] + r2[1] + r2[2]) / 1_000_000_000
    with open(results_path, "w") as f:
        f.write(String("{\n"))
        f.write(json_block("basic", r1))
        f.write(json_block("regex", r2))
        f.write(String('\t"overall_total_time":') + String(ott))
        f.write(String("\n}"))


def main() raises:
    var root = repo_root()
    var text = open(root + "/tests/taylorswift.txt", "r").read()

    print(
        "Benchmarking:",
        TEST_ROUNDS,
        "timed rounds after",
        WARMUP_ROUNDS,
        "warmup rounds\n",
    )

    var r1 = benchmark[BasicTokenizer](text, WARMUP_ROUNDS, TEST_ROUNDS)
    print_result("Basic Tokenizer", r1)

    var r2 = benchmark[RegexTokenizer[GPT4_SPLIT_PATTERN]](
        text, WARMUP_ROUNDS, TEST_ROUNDS
    )

    print_result("Regex Tokenizer", r2)

    print(
        "\nTotal average time: "
        + String(
            (r1[0] + r1[1] + r1[2] + r2[0] + r2[1] + r2[2]) / 1_000_000_000
        )
        + " seconds\n"
    )

    write_json(root + "/benchmarks/results/mojo.json", r1, r2)
