from std.python import Python, PythonObject

from .merge_manager import MergeManager, MergeRule

comptime SPECIAL_TOKENS_PATTERN = r"(['\"])(.*?)\1\s*:\s*(\d+)"


@fieldwise_init
struct TokenData(Equatable, Hashable, ImplicitlyCopyable, Movable, Writable):
    var token: String
    var id: Int

    def write_to(self, mut writer: Some[Writer]):
        writer.write("('", self.token, "': ", self.id, ")")

    def get_model_string(self) -> String:
        return self.token + " " + String(self.id)


struct VocabManager:
    var vocab: Dict[Int, List[UInt8]]
    var special_tokens: Dict[String, String]
    var inverse_special_tokens: Dict[Int, String]
    var regex: PythonObject

    var special_token_list: List[TokenData]

    def __init__(out self) raises:
        self.vocab = Dict[Int, List[UInt8]](capacity=64)
        self.special_tokens = Dict[String, String]()

        self.special_token_list = List[TokenData]()

        self.inverse_special_tokens = Dict[Int, String](capacity=64)
        self.regex = Python.import_module("regex")
        self.build_vocab()

    def clear(mut self):
        self.vocab.clear()
        self.special_tokens.clear()
        self.inverse_special_tokens.clear()
        self.special_token_list.clear()

    def add_token(mut self, mr: MergeRule) raises -> String:
        var new_vocab = self.get_token(Int(mr.input_id_pair.data[0]))
        new_vocab.extend(self.get_token(Int(mr.input_id_pair.data[1])))
        # Only for display: a merged token is a byte string, which need not be
        # valid UTF-8 on its own.
        var display = String(from_utf8_lossy=Span(new_vocab))
        self.add_token(mr.merge_id, new_vocab^)

        return display^

    @always_inline("nodebug")
    def add_token(mut self, idx: Int, var token: List[UInt8]) raises -> None:
        self.vocab[idx] = token^

    @always_inline("nodebug")
    def get_token(
        mut self, idx: Int, include_special: Bool = False
    ) raises -> List[UInt8]:
        """Return the raw bytes of token `idx`, empty if unknown."""
        var res = self.vocab.get(idx, List[UInt8]())
        if include_special and len(res) == 0:
            var special = self.get_special_token(idx)
            res = List[UInt8](Span(special.as_bytes()))
        return res^

    @always_inline("nodebug")
    def get_tokens(
        mut self, ids: List[Int], include_special: Bool = False
    ) raises -> String:
        """Decode `ids` back to text.

        Token bytes are accumulated first and decoded once at the end: a token
        can hold a partial UTF-8 sequence, so decoding per token would corrupt
        any multi-byte codepoint that straddles a token boundary. Invalid
        sequences in the result are replaced, mirroring minbpe's
        `decode("utf-8", errors="replace")`.
        """
        var buf = List[UInt8](capacity=len(ids) * 5)
        for i in range(len(ids)):
            buf.extend(self.get_token(ids[i], include_special))

        return String(from_utf8_lossy=Span(buf))

    def build_vocab(mut self) raises -> None:
        # Initialize with single-byte tokens.
        for idx in range(256):
            self.vocab[idx] = [UInt8(idx)]

    def register_special_tokens(mut self, special_tokens_str: String) raises:
        var compiled_pattern = self.regex.compile(SPECIAL_TOKENS_PATTERN)

        var special_tokens = self.regex.findall(
            compiled_pattern, special_tokens_str
        )

        for st in special_tokens:
            self.register_special_token(
                TokenData(String(st[1]), atol(String(st[2])))
            )

    def register_special_token(mut self, st: TokenData) raises:
        self.special_tokens[st.token] = String(st.id)
        self.inverse_special_tokens[st.id] = st.token
        self.special_token_list.append(st)

    def split_by_special_tokens(self, text: String) raises -> List[String]:
        if len(self.special_token_list) == 0:
            return [text]

        var special_pattern = String("(")

        for i in range(len(self.special_token_list) - 1):
            special_pattern += (
                String(self.regex.escape(self.special_token_list[i].token))
                + "|"
            )
        special_pattern += (
            String(
                self.regex.escape(
                    self.special_token_list[
                        len(self.special_token_list) - 1
                    ].token
                )
            )
            + ")"
        )

        var compiled_pattern = self.regex.compile(special_pattern)

        var special_chunks = self.regex.split(compiled_pattern, text)

        var res = List[String]()

        for sc in special_chunks:
            res.append(String(sc))
        return res^

    @always_inline("nodebug")
    def get_special_token_id(self, text: String) raises -> Int:
        return atol(self.special_tokens.get(text, "-1"))

    @always_inline("nodebug")
    def get_special_token(mut self, id: Int) raises -> String:
        return self.inverse_special_tokens.get(id, "")

    @always_inline("nodebug")
    def check_special_token_in_text(self, text: String) -> Bool:
        for st in self.special_token_list:
            if st.token in text:
                return True
        return False

    @staticmethod
    @always_inline("nodebug")
    def text_to_bytes(text: String) -> List[Int]:
        var bs = text.as_bytes()
        var ids = List[Int](capacity=len(bs))

        for i in range(len(bs)):
            ids.append(Int(bs[i]))
        return ids^

    @staticmethod
    @always_inline("nodebug")
    def text_to_bytes(text: String, mut ids: List[Int]):
        var bs = text.as_bytes()
        for i in range(len(bs)):
            ids.append(Int(bs[i]))
