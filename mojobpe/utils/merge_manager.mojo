from algorithm import parallelize
from math import min
from collections import Set

from .tat import print_list_int, distribute_jobs

from .generic_dict import Dict as GenericDict, Keyable, KeysBuilder

@value
struct IDPair(Keyable, KeyElement):
    var data: SIMD[DType.uint64, 2]

    fn __init__(inout self, id1: Int, id2: Int):
        self.data = SIMD[DType.uint64, 2](id1, id2)

    fn __init__(inout self, id1: String, id2: String) raises:
        self.data = SIMD[DType.uint64, 2](atol(id1), atol(id2))

    fn accept[T: KeysBuilder](self, inout keys_builder: T):
        keys_builder.add(self.data[0])
        keys_builder.add(self.data[1])

    fn __eq__(self, other: Self) -> Bool:
        return self.data == other.data

    fn __ne__(self, other: Self) -> Bool:
        return self.data != other.data

    fn __str__(self) -> String:
        return "(" + str(self.data[0]) + ", " + str(self.data[1]) + ")"

    fn get_model_string(self) -> String:
        return str(self.data[0]) + " " + str(self.data[1])

    fn as_chr(self) -> String:
        return chr(int(self.data[0])) + chr(int(self.data[1]))

    fn __hash__(self) -> Int:
        return hash(self.data[0] + 31 * self.data[1])


@value
struct MergeRule(Stringable):
    var input_id_pair: IDPair
    var merge_id: Int

    fn __init__(inout self, input_id_pair: IDPair, merge_id: Int):
        self.input_id_pair = input_id_pair
        self.merge_id = merge_id

    fn __init__(inout self, input_id1: Int, input_id2: Int, merge_id: Int):
        self.input_id_pair = IDPair(input_id1, input_id2)
        self.merge_id = merge_id

    fn __str__(self) -> String:
        return str(self.input_id_pair) + " -> " + str(self.merge_id)


struct MergeManager:
    var merge_rules: List[MergeRule]

    fn __init__(inout self):
        self.merge_rules = List[MergeRule]()

    fn clear(inout self):
        self.merge_rules = List[MergeRule]()

    fn add_rule(inout self, merge_rule: MergeRule):
        self.merge_rules.append(merge_rule)

    fn apply_rules(self, inout ids: List[Int]) raises -> None:
        while True:
            var merged = False
            var unique_pairs = MergeManager.get_unique_pairs(ids)
            for mr in self.merge_rules:
                for up in unique_pairs:
                    if mr[].input_id_pair == up[]:
                        MergeManager.merge(ids, mr[])
                        merged = True
                        break
                if merged:  # something found
                    break
            if not merged:  # nothing found anymore
                break

    @staticmethod
    fn __get_unique_pairs(ids: List[Int]) raises -> List[IDPair]:
        alias MAX_WORK_ITEMS = 200

        var n_jobs = len(ids) - 1
        var num_work_items = min(MAX_WORK_ITEMS, n_jobs // 100)

        var dj = distribute_jobs(n_jobs, num_work_items)

        var tmp = Pointer[Set[IDPair]].alloc(num_work_items)
        tmp[0] = Set[IDPair]()

        @parameter
        fn _calc(ip: Int):
            print("-------_")
            tmp[ip] = Set[IDPair]()
            print("-------")
            var end = min(
                dj[ip + 1] + 1, len(ids)
            )  # overlap to include all pairs
            for i in range(dj[ip], end):
                var p = IDPair(ids[i], ids[i + 1])

                tmp[ip].add(p)

        # parallelize[_calc](num_work_items)
        for i in range(num_work_items):
            _calc(i)

        for i in range(1, num_work_items):
            tmp[0].update(tmp[i])

        _ = dj[0]

        var unique_pairs = List[IDPair]()
        for e in tmp[0]:
            unique_pairs.append(e[])

        tmp.free()
        return unique_pairs

    @staticmethod
    fn get_unique_pairs(ids: List[Int]) raises -> List[IDPair]:
        var tmp = GenericDict[Bool]()

        var unique_pairs = List[IDPair]()

        var gone: Int = 0

        for i in range(0, len(ids) - 1):
            var p = IDPair(ids[i], ids[i + 1])
            if tmp.put(p, True):
                unique_pairs.append(p)

        return unique_pairs

    @staticmethod
    @always_inline("nodebug")
    fn update_stats_and_keys(
        inout stats: GenericDict[Int], inout keys: List[IDPair], ids: List[Int]
    ) raises -> None:
        for i in range(0, len(ids) - 1):
            var p = IDPair(ids[i], ids[i + 1])
            var val: Int = stats.get(p, 0) + 1
            if stats.put(p, val):
                keys.append(p)

    @staticmethod
    @always_inline("nodebug")
    fn update_stats_get_max(
        inout stats: GenericDict[Int], ids: List[Int]
    ) raises -> IDPair:
        var unique_id_pairs = List[IDPair]()
        MergeManager.update_stats_and_keys(stats, unique_id_pairs, ids)

        var max_pair = unique_id_pairs[0]
        var max_val = stats.get(max_pair, -1)

        for j in range(1, len(unique_id_pairs)):
            var val = stats.get(unique_id_pairs[j], -1)
            if val > max_val:
                max_val = val
                max_pair = unique_id_pairs[j]
        return max_pair

    # does not find the first occuring in the case of ties
    @staticmethod
    @always_inline("nodebug")
    fn ___update_stats_get_max(
        inout stats: GenericDict[Int], ids: List[Int]
    ) raises -> IDPair:
        var max_val = -1
        var max_id_pair = IDPair(ids[0], ids[1])

        for i in range(0, len(ids) - 1):
            var p = IDPair(ids[i], ids[i + 1])

            var val: Int = stats.get(p, 0) + 1
            _ = stats.put(p, val)

            if val > max_val:
                max_val = val
                max_id_pair = p

        return max_id_pair

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
