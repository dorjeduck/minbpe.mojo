from std.collections import Set
from std.hashlib import Hasher

from .tat import print_list_int, distribute_jobs


@fieldwise_init
struct IDPair(Equatable, Hashable, ImplicitlyCopyable, Movable, Writable):
    var data: SIMD[DType.uint64, 2]

    @always_inline("nodebug")
    def __init__(out self):
        self.data = SIMD[DType.uint64, 2](-1, -1)

    @always_inline("nodebug")
    def __init__(out self, id1: Int, id2: Int):
        self.data = SIMD[DType.uint64, 2](UInt64(id1), UInt64(id2))

    @always_inline("nodebug")
    def __init__(out self, id1: String, id2: String) raises:
        self.data = SIMD[DType.uint64, 2](UInt64(atol(id1)), UInt64(atol(id2)))

    @always_inline("nodebug")
    def packed(self) -> Int:
        """The pair as a single word, for use as a dictionary key.

        Both ids are below 2^32, so they pack into one Int. Hashing that is
        markedly cheaper than hashing the 16-byte SIMD, and the containers on
        the hot paths key on it rather than on `IDPair`.
        """
        return Int((self.data[0] << 32) | self.data[1])

    @staticmethod
    @always_inline("nodebug")
    def from_packed(key: Int) -> Self:
        var k = UInt64(key)
        return Self(Int(k >> 32), Int(k & 0xFFFFFFFF))

    @always_inline("nodebug")
    def __hash__[H: Hasher](self, mut hasher: H):
        # The reflection default would hash all 16 bytes of `data`.
        hasher.update((self.data[0] << 32) | self.data[1])

    @always_inline("nodebug")
    def write_to(self, mut writer: Some[Writer]):
        writer.write("(", self.data[0], ", ", self.data[1], ")")

    @always_inline("nodebug")
    def get_model_string(self) -> String:
        return String(self.data[0]) + " " + String(self.data[1])

    @always_inline("nodebug")
    def as_chr(self) -> String:
        return chr(Int(self.data[0])) + chr(Int(self.data[1]))


struct MergeRule(ImplicitlyCopyable, Movable, Writable):
    var input_id_pair: IDPair
    var merge_id: Int

    @always_inline("nodebug")
    def __init__(out self, input_id_pair: IDPair, merge_id: Int):
        self.input_id_pair = input_id_pair
        self.merge_id = merge_id

    @always_inline("nodebug")
    def __init__(out self, input_id1: Int, input_id2: Int, merge_id: Int):
        self.input_id_pair = IDPair(input_id1, input_id2)
        self.merge_id = merge_id

    @always_inline("nodebug")
    def write_to(self, mut writer: Some[Writer]):
        writer.write(self.input_id_pair, " -> ", self.merge_id)


struct PairCounts(Movable, Sized):
    """Counts of adjacent id pairs, kept in first-occurrence order.

    Mojo's `Dict` has no entry API, so counting through a `Counter` costs two
    hash probes per pair -- one to read the count, one to write it back -- and
    then another probe per distinct pair to find the maximum. Holding the
    counts in a list beside the index makes a repeated pair a single probe and
    the maximum scan hash-free. Pairs are keyed by `IDPair.packed()`.
    """

    var _slot: Dict[Int, Int]
    var _pairs: List[IDPair]
    var _counts: List[Int]

    def __init__(out self):
        self._slot = Dict[Int, Int]()
        self._pairs = List[IDPair]()
        self._counts = List[Int]()

    @always_inline("nodebug")
    def __len__(self) -> Int:
        return len(self._pairs)

    def clear(mut self):
        self._slot.clear()
        self._pairs.clear()
        self._counts.clear()

    @always_inline("nodebug")
    def add(mut self, key: Int) raises:
        """Count one occurrence of the pair packed into `key`."""
        var i = self._slot.get(key, -1)
        if i >= 0:
            self._counts[i] += 1
        else:
            self._slot[key] = len(self._pairs)
            self._pairs.append(IDPair.from_packed(key))
            self._counts.append(1)

    @always_inline("nodebug")
    def count(self, pair: IDPair) raises -> Int:
        """How often `pair` was seen, 0 if never."""
        var i = self._slot.get(pair.packed(), -1)
        return self._counts[i] if i >= 0 else 0

    def max_pair(self, merges_done: Int) raises -> IDPair:
        """The most frequent pair, ties going to the first occurrence.

        Args:
            merges_done: Merges completed so far, used for the error message.

        Raises:
            If no pairs were counted, i.e. the text is already fully merged
            and the requested vocab size cannot be reached.
        """
        if len(self._pairs) == 0:
            raise Error(
                "vocab size too large: the text is fully merged after ",
                merges_done,
                " merges, so no pair is left to merge (the largest usable",
                " vocab size for this text is ",
                256 + merges_done,
                ")",
            )

        var best = 0
        for i in range(1, len(self._counts)):
            if self._counts[i] > self._counts[best]:
                best = i
        return self._pairs[best]


struct MergeManager:
    var merge_rules: List[MergeRule]
    var merge_rules_dict: Dict[Int, Int]

    @always_inline("nodebug")
    def __init__(out self):
        self.merge_rules = List[MergeRule]()
        self.merge_rules_dict = Dict[Int, Int]()

    @always_inline("nodebug")
    def clear(mut self):
        self.merge_rules.clear()
        self.merge_rules_dict.clear()

    @always_inline("nodebug")
    def add_rule(mut self, merge_rule: MergeRule) raises:
        self.merge_rules.append(merge_rule)
        self.merge_rules_dict[
            merge_rule.input_id_pair.packed()
        ] = merge_rule.merge_id

    @always_inline("nodebug")
    def apply_rules(mut self, mut ids: List[Int]) raises -> None:
        var UPPER_VAL: Int = 100000

        while True:
            var min_val = UPPER_VAL
            var min_key = 0

            # No need to deduplicate the pairs first: merge ids are unique, so
            # repeated pairs simply re-find the same rank.
            for i in range(len(ids) - 1):
                var key = (ids[i] << 32) | ids[i + 1]
                var val = self.merge_rules_dict.get(key, UPPER_VAL)
                if val < min_val:
                    min_val = val
                    min_key = key

            if min_val < UPPER_VAL:
                MergeManager.merge(
                    ids, MergeRule(IDPair.from_packed(min_key), min_val)
                )
            else:
                break

    @always_inline("nodebug")
    def apply_rules_slow(mut self, mut ids: List[Int]) raises -> None:
        while True:
            var merged = False
            var unique_pairs = MergeManager.get_unique_pairs(ids)
            for rule in self.merge_rules:
                for up in unique_pairs:
                    if rule.input_id_pair == up:
                        MergeManager.merge(ids, rule)
                        merged = True
                        break
                if merged:
                    break
            if not merged:
                break

    @staticmethod
    def get_unique_pairs(ids: List[Int]) raises -> List[IDPair]:
        var tmp = Set[Int]()

        var unique_pairs = List[IDPair]()

        for i in range(0, len(ids) - 1):
            var key = (ids[i] << 32) | ids[i + 1]
            if not tmp.insert(key):
                unique_pairs.append(IDPair.from_packed(key))

        return unique_pairs^

    @staticmethod
    @always_inline("nodebug")
    def update_stats(mut stats: PairCounts, ids: List[Int]) raises -> None:
        for i in range(0, len(ids) - 1):
            stats.add((ids[i] << 32) | ids[i + 1])

    @staticmethod
    @always_inline("nodebug")
    def update_stats_get_max(
        mut stats: PairCounts, ids: List[Int], merges_done: Int = 0
    ) raises -> IDPair:
        MergeManager.update_stats(stats, ids)
        return stats.max_pair(merges_done)

    @staticmethod
    @always_inline("nodebug")
    def merge(mut ids: List[Int], merge_rule: MergeRule) -> None:
        var i = 0
        var gone = 0
        while i < len(ids):
            if (
                ids[i] == Int(merge_rule.input_id_pair.data[0])
                and i < len(ids) - 1
                and ids[i + 1] == Int(merge_rule.input_id_pair.data[1])
            ):
                ids[i - gone] = merge_rule.merge_id
                i += 2
                gone += 1
            else:
                if gone > 0:
                    ids[i - gone] = ids[i]
                i += 1
        ids.resize(len(ids) - gone, 0)

    @staticmethod
    def print_merge_round(
        round: Int,
        total: Int,
        merge_rule: MergeRule,
        new_vocab: String,
        occurrences: Int,
    ) -> None:
        print(
            "merge "
            + String(round)
            + "/"
            + String(total)
            + ": "
            + String(merge_rule)
            + " (b'"
            + new_vocab
            + "') had "
            + String(occurrences)
            + " occurrences"
        )
