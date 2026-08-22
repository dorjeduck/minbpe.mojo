from std.collections import Set
from std.testing import (
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
    TestSuite,
)

from mojobpe import BasicTokenizer, RegexTokenizer
from mojobpe.standards import (
    GPT2_SPLIT_PATTERN,
    GPT4_SPLIT_PATTERN,
    GPT4_SPECIAL_TOKENS,
)
from mojobpe.utils import IDPair, MergeManager, MergeRule, PairCounts

comptime TAYLORSWIFT = "tests/taylorswift.txt"


def corpus() raises -> String:
    return open(TAYLORSWIFT, "r").read()


def test_quickstart() raises:
    """The documented quickstart example must reproduce minbpe's output."""
    var text = "aaabdaaabac"
    var tokenizer = BasicTokenizer()
    tokenizer.train(text, 256 + 3)

    var expected: List[Int] = [258, 100, 258, 97, 99]
    assert_equal(tokenizer.encode(text), expected)
    assert_equal(tokenizer.decode(expected), text)


def test_basic_roundtrip() raises:
    var text = corpus()
    var tokenizer = BasicTokenizer()
    tokenizer.train(text, 512)

    var encoded = tokenizer.encode(text)
    assert_true(len(encoded) < text.byte_length())
    assert_equal(tokenizer.decode(encoded), text)


def test_regex_roundtrip() raises:
    var text = corpus()
    var tokenizer = RegexTokenizer[GPT4_SPLIT_PATTERN]()
    tokenizer.train(text, 512, False)

    var encoded = tokenizer.encode(text)
    assert_true(len(encoded) < text.byte_length())
    assert_equal(tokenizer.decode(encoded), text)


def test_basic_save_load() raises:
    var text = "aaabdaaabac"
    var tokenizer = BasicTokenizer()
    tokenizer.train(text, 256 + 3)
    var expected = tokenizer.encode(text)

    tokenizer.save("tests/tmp_basic")

    var loaded = BasicTokenizer()
    loaded.load("tests/tmp_basic")
    assert_equal(loaded.encode(text), expected)
    # `load` must replay the merges into the vocab, or the loaded tokenizer
    # encodes correctly but decodes to a truncated string.
    assert_equal(loaded.decode(loaded.encode(text)), text)


def test_regex_save_load() raises:
    var text = corpus()
    var tokenizer = RegexTokenizer[GPT4_SPLIT_PATTERN]()
    tokenizer.register_special_tokens(GPT4_SPECIAL_TOKENS)
    tokenizer.train(text, 300, False)
    var expected = tokenizer.encode(text)

    tokenizer.save("tests/tmp_regex")

    var loaded = RegexTokenizer[GPT4_SPLIT_PATTERN]()
    loaded.load("tests/tmp_regex")
    assert_equal(loaded.encode(text), expected)
    assert_equal(loaded.decode(loaded.encode(text)), text)


def test_special_tokens() raises:
    var tokenizer = RegexTokenizer[GPT4_SPLIT_PATTERN]()
    tokenizer.register_special_tokens(GPT4_SPECIAL_TOKENS)
    tokenizer.train("hello world hello", 260, False)

    var encoded = tokenizer.encode("hello<|endoftext|>world")
    assert_true(100257 in encoded)
    assert_equal(tokenizer.decode(encoded), "hello<|endoftext|>world")


def test_merge_manager_unique_pairs() raises:
    # "abab" -> pairs (a,b) (b,a) (a,b); the repeat must be reported once,
    # in first-occurrence order.
    var ids: List[Int] = [97, 98, 97, 98]
    var pairs = MergeManager.get_unique_pairs(ids)
    assert_equal(len(pairs), 2)
    assert_true(pairs[0] == IDPair(97, 98))
    assert_true(pairs[1] == IDPair(98, 97))


def test_merge_manager_merge() raises:
    var ids: List[Int] = [97, 98, 99, 97, 98]
    var expected: List[Int] = [256, 99, 256]
    MergeManager.merge(ids, MergeRule(IDPair(97, 98), 256))
    assert_equal(ids, expected)


def test_merge_manager_stats() raises:
    var stats = PairCounts()
    var ids: List[Int] = [97, 98, 97, 98]
    MergeManager.update_stats(stats, ids)

    assert_equal(len(stats), 2)
    assert_equal(stats.count(IDPair(97, 98)), 2)
    assert_equal(stats.count(IDPair(98, 97)), 1)
    assert_equal(stats.count(IDPair(1, 2)), 0)
    # Ties go to the first occurrence, in insertion order.
    assert_true(stats.max_pair(0) == IDPair(97, 98))


def test_idpair_as_key() raises:
    """IDPair relies on reflection-derived __eq__/__hash__ to key the stdlib
    containers that replaced the vendored compact-dict."""
    var a = IDPair(1, 2)
    var b = IDPair(1, 2)
    var c = IDPair(2, 1)

    assert_true(a == b)
    assert_true(a != c)
    assert_equal(hash(a), hash(b))

    var d = Dict[IDPair, Int]()
    d[a] = 7
    assert_equal(d.get(b, -1), 7)
    assert_equal(d.get(c, -1), -1)

    var s = Set[IDPair]()
    assert_false(Bool(s.insert(a)))
    assert_true(Bool(s.insert(b)))
    assert_true(c not in s)


def test_idpair_model_string() raises:
    assert_equal(IDPair(12, 34).get_model_string(), "12 34")
    assert_equal(String(IDPair(12, 34)), "(12, 34)")
    assert_equal(String(MergeRule(IDPair(12, 34), 256)), "(12, 34) -> 256")


def test_utf8_roundtrip() raises:
    """Multi-byte codepoints must survive encode/decode.

    The vocab stores raw bytes, so a token may hold a partial UTF-8 sequence;
    `get_tokens` therefore concatenates bytes and decodes once at the end.
    """
    var unit = "caf\u00e9 na\u00efve \u2014 \U0001f525 \u4f60\u597d "
    var text = String(capacity=unit.byte_length() * 40)
    for _ in range(40):
        text += unit
    var tokenizer = BasicTokenizer()
    tokenizer.train(text, 276)

    var decoded = tokenizer.decode(tokenizer.encode(text))
    assert_equal(decoded, text)
    assert_equal(decoded.byte_length(), text.byte_length())


def test_utf8_roundtrip_full_corpus() raises:
    """The corpus contains non-ASCII punctuation; it must round-trip exactly."""
    var text = corpus()
    var tokenizer = BasicTokenizer()
    tokenizer.train(text, 512)

    var decoded = tokenizer.decode(tokenizer.encode(text))
    assert_equal(decoded.byte_length(), text.byte_length())
    assert_equal(decoded, text)


def test_vocab_size_too_large() raises:
    """Asking for more merges than the text supports must raise, not crash.

    "abab" collapses to a single token after 3 merges, so a 4th has no pair
    left to work on.
    """
    var tokenizer = BasicTokenizer()
    with assert_raises(contains="vocab size too large"):
        tokenizer.train("abab", 256 + 8)


def test_vocab_size_too_large_regex() raises:
    var tokenizer = RegexTokenizer[GPT4_SPLIT_PATTERN]()
    with assert_raises(contains="vocab size too large"):
        tokenizer.train("abab", 256 + 8, False)


def test_clear_keeps_pattern() raises:
    """`clear` drops learned state; the split pattern is configuration."""
    var tokenizer = RegexTokenizer[GPT4_SPLIT_PATTERN]()
    tokenizer.train("hello world hello world", 260, False)
    tokenizer.clear()

    assert_equal(tokenizer.get_split_pattern(), GPT4_SPLIT_PATTERN)
    # Must still be usable after clearing.
    tokenizer.train("hello world hello world", 260, False)
    assert_equal(tokenizer.decode(tokenizer.encode("hello")), "hello")


def test_set_pattern() raises:
    var tokenizer = RegexTokenizer[GPT4_SPLIT_PATTERN]()
    tokenizer.set_pattern(GPT2_SPLIT_PATTERN)

    assert_equal(tokenizer.get_split_pattern(), GPT2_SPLIT_PATTERN)
    tokenizer.train("hello world hello world", 260, False)
    assert_equal(tokenizer.decode(tokenizer.encode("hello")), "hello")


def test_none_raise_rejects_special_token() raises:
    var tokenizer = RegexTokenizer[GPT4_SPLIT_PATTERN, "none_raise"]()
    tokenizer.register_special_tokens(GPT4_SPECIAL_TOKENS)
    tokenizer.train("hello world hello world", 260, False)

    assert_equal(tokenizer.decode(tokenizer.encode("hello")), "hello")
    with assert_raises(contains="none_raise"):
        _ = tokenizer.encode("hello<|endoftext|>world")


def test_idpair_packed_roundtrip() raises:
    """`packed` is the dictionary key on the hot paths; it must be lossless."""
    for a in [0, 1, 255, 256, 511, 100257, 4294967295]:
        for b in [0, 1, 255, 256, 511, 100257, 4294967295]:
            var p = IDPair(a, b)
            assert_equal(IDPair.from_packed(p.packed()), p)

    assert_true(IDPair(1, 2).packed() != IDPair(2, 1).packed())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
