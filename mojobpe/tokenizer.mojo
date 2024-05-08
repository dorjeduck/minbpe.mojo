from .utils import MergeManager,VocabManager

trait TokenizationStrategy:    

    fn __init__(inout self) raises:
        ...
    fn set(inout self,merge_manager_ptr:Pointer[MergeManager],vocab_manager_ptr:Pointer[VocabManager]):
        ...
    fn train(inout self,text:String,vocab_size:Int,verbose:Bool=False) raises -> None:
        ...
    fn encode(self,text:String)raises->List[Int]:
        ...
    fn decode(self, ids:List[Int]) raises -> String:
        ...
    fn get_split_pattern(self)->String:
        ...
    fn load(inout self, model_file:String) raises -> None:
        ...
    fn save(self, model_file:String) raises -> None:
        ...
    fn clear(inout self) raises:
        ...


struct Tokenizer[TOKENIZATION_STRATEGY:TokenizationStrategy]:
    #A general tokenizer struct using composition for managing vocab, merges, and tokenization strategies."""
    
    var tokenization_strategy:TOKENIZATION_STRATEGY 
    var merge_manager:MergeManager
    var vocab_manager:VocabManager
    
    fn __init__(inout self) raises:

        self.tokenization_strategy = TOKENIZATION_STRATEGY()
        self.merge_manager = MergeManager() 
        self.vocab_manager = VocabManager()
   
        self.tokenization_strategy.set(Pointer.address_of(self.merge_manager),Pointer.address_of(self.vocab_manager))
        
    fn register_special_tokens(inout self, special_tokens_str:String) raises:
        self.vocab_manager.register_special_tokens(special_tokens_str)
   
    fn train(inout self, text:String, vocab_size:Int, verbose:Bool=False) raises:
        self.tokenization_strategy.train(text, vocab_size,verbose)

    fn encode(self, text:String) raises -> List[Int]:
        return self.tokenization_strategy.encode(text)

    fn decode(self, ids:List[Int]) raises -> String:
        return self.tokenization_strategy.decode(ids)

    fn load(inout self, model_file:String) raises -> None:
        debug_assert( model_file.split('.')[-1] == "model","model file must have the .model extension: " + model_file)
        self.tokenization_strategy.clear()
        self.tokenization_strategy.load(model_file)
       
    fn save(self, file_prefix:String) raises -> None:
        var model_file = file_prefix + ".model"
        self.tokenization_strategy.save(model_file)