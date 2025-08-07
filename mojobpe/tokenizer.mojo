from .utils import MergeManager, VocabManager


trait Encoder:
    fn encode(mut self, text: String) raises -> List[Int]:
        ...


trait Decoder:
    fn decode(mut self, ids: List[Int]) raises -> String:
        ...


trait Trainable:
    fn train(
        mut self, text: String, vocab_size: Int, verbose: Bool = False
    ) raises -> None:
        ...


trait Persistable:
    fn load(mut self, s: String) raises -> None:
        ...

    fn save(self, s: String) raises -> None:
        ...


trait Tokenizer(Decoder, Encoder, Persistable, Trainable):
    fn __init__(out self) raises:
        ...

    fn get_split_pattern(self) -> String:
        ...

    fn clear(mut self) raises:
        ...
