from algorithm import parallelize
from collections.vector import InlinedFixedVector
from math import min
from python import Python

from .merge_manager import MergeManager

from .string_dict import Dict as StringDict
from .tat import distribute_jobs, print_list_int

alias SPECIAL_TOKENS_PATTERN = r"(['\"])(.*?)\1\s*:\s*(\d+)"


@value
struct TokenData:
    var token: String
    var id: Int

    fn __eq__(self, other: Self) -> Bool:
        return self.id == other.id and self.token == other.token

    fn __ne__(self, other: Self) -> Bool:
        return self.id != other.id or self.token != other.token

    fn __str__(self) -> String:
        return "('" + self.token + "': " + str(self.id) + ")"

    fn __hash__(self) -> Int:
        return hash(self.id) ^ hash(self.token)

    fn get_model_string(self) -> String:
        return self.token + " " + str(self.id)


struct VocabManager:
    var vocab: StringDict[String]
    var special_tokens: StringDict[String]
    var inverse_special_tokens: StringDict[String]
    var regex: PythonObject

    var special_token_list: List[TokenData]

    fn __init__(inout self) raises:
        self.vocab = StringDict[String]()
        self.special_tokens = StringDict[String]()

        self.special_token_list = List[TokenData]()

        self.inverse_special_tokens = StringDict[String]()
        self.regex = Python.import_module("regex")
        self.build_vocab()

    fn clear(inout self):
        self.vocab = StringDict[String]()
        self.special_tokens = StringDict[String]()
        self.inverse_special_tokens = StringDict[String]()
        self.special_token_list = List[TokenData]()

    @always_inline("nodebug")
    fn add_token(inout self, idx: Int, token: String) -> None:
        self.vocab.put(str(idx), token)

    @always_inline("nodebug")
    fn get_token(self, idx: Int, include_special: Bool = False) -> String:
        var res = self.vocab.get(str(idx), "")
        if include_special and len(res) == 0:
            res = self.get_special_token(idx)
        return res

    @always_inline("nodebug")
    fn get_tokens_simple(
        self, ids: List[Int], include_special: Bool = False
    ) raises -> String:
        var res: String = ""
        for i in range(len(ids)):
            res += self.get_token(ids[i], include_special)
        return res

    @always_inline("nodebug")
    fn get_tokens(
        self, ids: List[Int], include_special: Bool = False
    ) raises -> String:
        alias MAX_WORK_ITEMS = 200
        var n_jobs = len(ids)

        if n_jobs < 1000:
            return self.get_tokens_simple(ids, include_special)
        else:
            var num_work_items = min(MAX_WORK_ITEMS, n_jobs // 100)
            var dj = distribute_jobs(n_jobs, num_work_items)

            var rl = List[String](capacity=num_work_items + 1)
            rl.resize(num_work_items + 1, "")

            @parameter
            fn _calc(ip: Int):
                rl[ip] = String("")
                for i in range(dj[ip], dj[ip + 1]):
                    rl[ip] += self.get_token(ids[i], include_special)

            parallelize[_calc](num_work_items)

            _ = dj[0]  # dj lifetime insurance ....

            var res = rl[0]
            for i in range(1, num_work_items):
                res += rl[i]

            return res

    fn build_vocab(inout self) -> None:  # , special_tokens):
        # Initialize with single-byte tokens.
        for idx in range(256):
            self.vocab.put(str(idx), chr(idx))

    fn register_special_tokens(inout self, special_tokens_str: String) raises:
        var compiled_pattern = self.regex.compile(SPECIAL_TOKENS_PATTERN)

        var special_tokens = self.regex.findall(
            compiled_pattern, special_tokens_str
        )

        for st in special_tokens:
            self.register_special_token(TokenData(st[1], atol(st[2])))

    fn register_special_token(inout self, st: TokenData):
        self.special_tokens.put(st.token, st.id)
        self.inverse_special_tokens.put(st.id, st.token)
        self.special_token_list.append(st)

    fn split_by_special_tokens(self, text: String) raises -> List[String]:
        if len(self.special_token_list) == 0:
            return List[String](text)

        var special_pattern = String("(")

        for i in range(len(self.special_token_list) - 1):
            special_pattern += (
                self.regex.escape(self.special_token_list[i].token) + "|"
            )
        special_pattern += (
            self.regex.escape(self.special_token_list[-1].token) + ")"
        )

        var compiled_pattern = self.regex.compile(special_pattern)

        var special_chunks = self.regex.split(compiled_pattern, text)

        var res = List[String]()

        for sc in special_chunks:
            res.append(sc)
        return res

    @always_inline("nodebug")
    fn get_special_token_id(self, text: String) raises -> Int:
        return atol(self.special_tokens.get(text, -1))

    @always_inline("nodebug")
    fn get_special_token(self, id: Int) -> String:
        return self.inverse_special_tokens.get(id, "")

    @always_inline("nodebug")
    fn check_special_token_in_text(self, text: String) -> Bool:
        for st in self.special_token_list:
            if st[].token in text:
                return True
        return False

    @staticmethod
    @always_inline("nodebug")
    fn text_to_bytes(text: String) -> List[Int]:
        var _ids = text.as_bytes()
        var ids = List[Int]()

        # soon Mojo will natively move to uint8
        for i8 in _ids:
            if i8[] >= 0:
                ids.append(int(i8[]))
            else:
                ids.append(int(i8[]) + 256)
        return ids
