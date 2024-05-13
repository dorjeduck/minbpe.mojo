from math import min
from collections import Set

from .tat import print_list_int, distribute_jobs
from .generic_dict import (
    Dict as GenericDict,
    Keyable,
    KeysBuilder,
    Set as GenericSet,
)
from .generic_dict import CounterDict


@value
struct IDPair(Keyable, KeyElement):
    var data: SIMD[DType.uint64, 2]

    @always_inline("nodebug")
    fn __init__(inout self):
        self.data = SIMD[DType.uint64, 2](-1, -1)

    @always_inline("nodebug")
    fn __init__(inout self, id1: Int, id2: Int):
        self.data = SIMD[DType.uint64, 2](id1, id2)

    @always_inline("nodebug")
    fn __init__(inout self, id1: String, id2: String) raises:
        self.data = SIMD[DType.uint64, 2](atol(id1), atol(id2))

    @always_inline("nodebug")
    fn __eq__(self, other: Self) -> Bool:
        return self.data == other.data

    @always_inline("nodebug")
    fn __ne__(self, other: Self) -> Bool:
        return self.data != other.data

    @always_inline("nodebug")
    fn __str__(self) -> String:
        return "(" + str(self.data[0]) + ", " + str(self.data[1]) + ")"

    @always_inline("nodebug")
    fn __hash__(self) -> Int:
        return hash(self.data[0] + 31 * self.data[1])

    @always_inline("nodebug")
    fn accept[T: KeysBuilder](self, inout keys_builder: T):
        keys_builder.add(self.data[0])
        keys_builder.add(self.data[1])

    @always_inline("nodebug")
    fn get_model_string(self) -> String:
        return str(self.data[0]) + " " + str(self.data[1])

    @always_inline("nodebug")
    fn as_chr(self) -> String:
        return chr(int(self.data[0])) + chr(int(self.data[1]))


@value
struct MergeRule(Stringable):
    var input_id_pair: IDPair
    var merge_id: Int

    @always_inline("nodebug")
    fn __init__(inout self, input_id_pair: IDPair, merge_id: Int):
        self.input_id_pair = input_id_pair
        self.merge_id = merge_id

    @always_inline("nodebug")
    fn __init__(inout self, input_id1: Int, input_id2: Int, merge_id: Int):
        self.input_id_pair = IDPair(input_id1, input_id2)
        self.merge_id = merge_id

    @always_inline("nodebug")
    fn __str__(self) -> String:
        return str(self.input_id_pair) + " -> " + str(self.merge_id)


struct MergeManager:
    var merge_rules: List[MergeRule]
    var merge_rules_dict: GenericDict[Int]
    var unique_id_pairs: List[IDPair]

    @always_inline("nodebug")
    fn __init__(inout self):
        self.merge_rules = List[MergeRule]()
        self.merge_rules_dict = GenericDict[Int](capacity=64)
        self.unique_id_pairs = List[IDPair](capacity=64)

    @always_inline("nodebug")
    fn clear(inout self):
        self.merge_rules.clear()
        self.merge_rules_dict = GenericDict[Int]()

    @always_inline("nodebug")
    fn add_rule(inout self, merge_rule: MergeRule) raises:
        self.merge_rules.append(merge_rule)
        _ = self.merge_rules_dict.put(
            merge_rule.input_id_pair, merge_rule.merge_id
        )

    @always_inline("nodebug")
    fn apply_rules(inout self, inout ids: List[Int]) raises -> None:
        var UPPER_VAL: Int = 100000

        var min_val = UPPER_VAL
        var min_pair = IDPair()

        while True:
            var min_val = UPPER_VAL
            self.unique_id_pairs.clear()
            MergeManager.get_unique_pairs(ids, self.unique_id_pairs)
            for up in self.unique_id_pairs:
                var val = self.merge_rules_dict.get(up[], UPPER_VAL)
                if val < min_val:
                    min_val = val
                    min_pair = up[]
            if min_val < UPPER_VAL:
                MergeManager.merge(ids, MergeRule(min_pair, min_val))
            else:
                break

    # @always_inline("nodebug")
    # fn apply_rules_slow(inout self, inout ids: List[Int]) raises -> None:
    #
    #    while True:
    #        var merged = False
    #        self.unique_id_pairs.clear()
    #        MergeManager.get_unique_pairs(ids,self.unique_id_pairs)
    #        for rule in self.merge_rules:
    #            var rule_value = rule[]
    #            for up in self.unique_id_pairs:
    #                if rule_value.input_id_pair == up[]:
    #                    MergeManager.merge(ids, rule_value)
    #                    merged = True
    #                    break
    #            if merged:
    #                break
    #        if not merged:
    #            break

    @always_inline("nodebug")
    fn update_stats_get_max(
        inout self, inout stats: CounterDict, ids: List[Int]
    ) raises -> IDPair:
        self.unique_id_pairs.clear()
        MergeManager.update_stats_and_keys(stats, self.unique_id_pairs, ids)

        var max_pair = self.unique_id_pairs[0]
        var max_val = stats.get(max_pair, -1)

        for j in range(1, len(self.unique_id_pairs)):
            var val = stats.get(self.unique_id_pairs[j], -1)
            if val > max_val:
                max_val = val
                max_pair = self.unique_id_pairs[j]
        return max_pair

    @staticmethod
    fn get_unique_pairs(
        ids: List[Int], inout unique_pairs: List[IDPair]
    ) raises:
        var tmp = GenericSet()

        for i in range(0, len(ids) - 1):
            var p = IDPair(ids[i], ids[i + 1])
            if tmp.put(p):
                unique_pairs.append(p)

    @staticmethod
    @always_inline("nodebug")
    fn update_stats_and_keys(
        inout stats: CounterDict, inout keys: List[IDPair], ids: List[Int]
    ) raises -> None:
        for i in range(0, len(ids) - 1):
            var p = IDPair(ids[i], ids[i + 1])
            if stats.increase(p):
                keys.append(p)

    @staticmethod
    @always_inline("nodebug")
    fn merge(inout ids: List[Int], merge_rule: MergeRule) -> None:
        var i = 0
        var gone = 0
        while i < len(ids):
            if (
                ids[i] == int(merge_rule.input_id_pair.data[0])
                and i < len(ids) - 1
                and ids[i + 1] == int(merge_rule.input_id_pair.data[1])
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
    fn print_merge_round(
        round: Int,
        total: Int,
        merge_rule: MergeRule,
        new_vocab: String,
        occurrences: Int,
    ) -> None:
        print(
            "merge "
            + str(round)
            + "/"
            + total
            + ": "
            + merge_rule
            + " (b'"
            + new_vocab
            + "') had "
            + str(occurrences)
            + " occurrences"
        )
