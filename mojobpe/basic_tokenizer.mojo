from std.collections import Counter

from .utils import IDPair, MergeManager, MergeRule, VocabManager

from .tokenizer import Tokenizer


struct BasicTokenizer(Tokenizer):
    var merge_manager: MergeManager
    var vocab_manager: VocabManager

    def __init__(out self) raises: 
        self.merge_manager = MergeManager()
        self.vocab_manager = VocabManager()

    def clear(mut self) raises:
        self.merge_manager.clear()
        self.vocab_manager.clear()
        self.vocab_manager.build_vocab()

    def get_split_pattern(self) -> String:
        return ""

    def train(
        mut self, text: String, vocab_size: Int, verbose: Bool = False
    ) raises -> None:
        if verbose:
            print("Training BasicTokenizer...")

        debug_assert(vocab_size >= 256, "vocab size too small (<256)")

        var num_merges = vocab_size - 256
        var ids = VocabManager.text_to_bytes(text)

        self.vocab_manager.build_vocab()

        var stats = Counter[IDPair]()
        for i in range(num_merges):
            stats.clear()

            var max_pair = MergeManager.update_stats_get_max(stats, ids, i)

            var idx = 256 + i
            var merge_rule = MergeRule(max_pair, idx)

            MergeManager.merge(ids, merge_rule)

            self.merge_manager.add_rule(merge_rule)
            var new_vocab = self.vocab_manager.add_token(merge_rule)

            if verbose:
                MergeManager.print_merge_round(
                    i + 1,
                    num_merges,
                    merge_rule,
                    new_vocab,
                    stats.get(max_pair, -1),
                )

    def encode(mut self, text: String) raises -> List[Int]:
        var ids = VocabManager.text_to_bytes(text)
        self.merge_manager.apply_rules(ids)
        return ids^

    def decode(mut self, ids: List[Int]) raises -> String:
        return self.vocab_manager.get_tokens(ids)

    def load(mut self, file_prefix: String) raises -> None:
        """Inverse of save(): reads `file_prefix` + ".model"."""
        var model_file = file_prefix + ".model"

        # read the model file
        with open(model_file, "r") as f:
            var lines = f.read().splitlines()
            # check version
            debug_assert(
                lines[0].strip() == "minbpe v1",
                "wrong model version: " + lines[0].strip(),
            )
            # no pattern (empty line)
            # no special tokens (0 line)
            var idx = 256
            for line_number in range(3, len(lines)):
                if lines[line_number].strip().byte_length() == 0:
                    continue
                var t = lines[line_number].strip().split(" ")
                var rule = MergeRule(IDPair(String(t[0]), String(t[1])), idx)
                self.merge_manager.add_rule(rule)
                # Replay the merge into the vocab; without this the loaded
                # tokenizer can encode but not decode.
                _ = self.vocab_manager.add_token(rule)
                idx += 1

    def save(self, file_prefix: String) raises -> None:
        """Write `file_prefix` + ".model", the file `load` reads back."""
        with open(file_prefix + ".model", "w") as f:
            # write the version, pattern and merges, that's all that's needed
            f.write("minbpe v1\n")
            f.write("\n")  # no special pattern
            f.write("0\n")  # no special token

            for mr in self.merge_manager.merge_rules:
                f.write(mr.input_id_pair.get_model_string() + "\n")
