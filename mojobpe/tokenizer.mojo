from .utils import MergeManager,VocabManager
from .utils.mostring import MoString

trait Encoder:
    fn encode(inout self,text:String)raises->List[Int]:
        ...
trait Decoder: 
    fn decode(inout self, ids:List[Int]) raises -> String:
        ...
trait Trainable:
     fn train(inout self,text:String,vocab_size:Int,verbose:Bool=False) raises -> None:
        ...

trait Persistable:
    fn load(inout self, s:String) raises -> None:
        ...
    fn save(self, s:String) raises -> None:
        ...

trait Tokenizer(Encoder,Decoder,Trainable,Persistable):    

    fn __init__(inout self) raises:
        ...
   
    fn get_split_pattern(self)->String:
        ...
    fn clear(inout self) raises:
        ...

