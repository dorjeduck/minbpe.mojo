from time import perf_counter_ns as now

from mojobpe import Tokenizer, BasicTokenizer, RegexTokenizer
from mojobpe.standards import GPT4_SPLIT_PATTERN, GPT4_SPECIAL_TOKENS
from mojobpe.utils.tat import print_list_int

alias TEST_ROUNDS = 1
alias VERBOSE = False


fn benchmark[
    TK: Tokenizer
](mut tokenizer: TK, text: String, test_rounds: Int) raises -> List[Float64]:
    var s1 = now()
    for _ in range(test_rounds):
        tokenizer.train(text, 512, VERBOSE)

    var e1 = (now() - s1) / test_rounds

    var s2 = now()
    var encoded = List[Int]()
    for _ in range(test_rounds):
        encoded = tokenizer.encode(text)

    var e2 = (now() - s2) / test_rounds

    var s3 = now()
    var decoded = String("")
    for _ in range(test_rounds):
        decoded = tokenizer.decode(encoded)

    var e3 = (now() - s3) / test_rounds

    _ = decoded

    return List[Float64](e1, e2, e3)


fn print_result(name: String, r: List[Float64]):
    print("-------------------------------------------------------------")
    print("Benchmark results for", name, "\n")
    print("Average training time: " + String(r[0] / 1_000_000_000) + " seconds")
    print("Average encoding time: " + String(r[1] / 1_000_000_000) + " seconds")
    print(
        "Average decoding time: " + String(r[2] / 1_000_000_000) + " seconds\n"
    )
    print("Sum: " + String((r[0] + r[1] + r[2]) / 1_000_000_000) + " seconds")
    print("-------------------------------------------------------------")


fn json_block(name: String, data: List[Float64]) -> String:
    var total = (data[0] + data[1] + data[2]) / 1_000_000_000
    var res: String = ""
    res += '\t"' + name + '": {\n'
    res += '\t\t"training_time": ' + String(data[0] / 1_000_000_000) + ",\n"
    res += '\t\t"encoding_time": ' + String(data[1] / 1_000_000_000) + ",\n"
    res += '\t\t"decoding_time": ' + String(data[2] / 1_000_000_000) + ",\n"
    res += '\t\t"total_time": ' + String(total) + "\n"
    res += "\t},\n"
    return res


fn write_json(r1: List[Float64], r2: List[Float64]) raises:
    var ott = (r1[0] + r1[1] + r1[2] + r2[0] + r2[1] + r2[2]) / 1_000_000_000
    with open("results_mojo.json", "w") as f:
        f.write(String("{\n"))
        f.write(json_block("basic", r1))
        f.write(json_block("regex", r2))
        f.write(String('\t"overall_total_time":') + String(ott))
        f.write(String("\n}"))


fn main() raises:
    var text = open("tests/taylorswift.txt", "r").read()

    var tokenizer = BasicTokenizer()
    var tokenizer2 = RegexTokenizer[GPT4_SPLIT_PATTERN]()

    var r1 = benchmark(tokenizer, text, TEST_ROUNDS)
    print_result("Basic Tokenizer", r1)

    var r2 = benchmark(tokenizer2, text, TEST_ROUNDS)

    print_result("Regex Tokenizer", r2)

    print(
        "\nTotal average time: "
        + String(
            (r1[0] + r1[1] + r1[2] + r2[0] + r2[1] + r2[2]) / 1_000_000_000
        )
        + " seconds\n"
    )

    write_json(r1, r2)
