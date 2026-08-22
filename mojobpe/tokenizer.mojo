trait Encoder:
    def encode(mut self, text: String) raises -> List[Int]:
        ...


trait Decoder:
    def decode(mut self, ids: List[Int]) raises -> String:
        ...


trait Trainable:
    def train(
        mut self, text: String, vocab_size: Int, verbose: Bool = False
    ) raises -> None:
        ...


trait Persistable:
    def load(mut self, s: String) raises -> None:
        ...

    def save(self, s: String) raises -> None:
        ...


trait Tokenizer(Decoder, Encoder, Persistable, Trainable):
    def __init__(out self) raises:
        ...

    def get_split_pattern(self) -> String:
        ...

    def clear(mut self) raises:
        ...
