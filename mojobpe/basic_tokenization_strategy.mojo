from .utils import IDPair, MergeManager,MergeRule,VocabManager
from .utils.generic_dict import CounterDict
from .utils.tat import IntKey,MoBench

from .tokenizer import TokenizationStrategy

struct BasicTokenizationStrategy(TokenizationStrategy):
   
    var merge_manager_ptr:Pointer[MergeManager]
    var vocab_manager_ptr:Pointer[VocabManager]

    fn __init__(inout self) raises:
        self.merge_manager_ptr = Pointer[MergeManager]()
        self.vocab_manager_ptr = Pointer[VocabManager]()


    fn set(inout self,merge_manager_ptr:Pointer[MergeManager],vocab_manager_ptr:Pointer[VocabManager]):
        self.merge_manager_ptr = merge_manager_ptr
        self.vocab_manager_ptr = vocab_manager_ptr

    fn clear(inout self) raises:
        self.merge_manager_ptr[].clear()
        self.vocab_manager_ptr[].clear()
        self.vocab_manager_ptr[].build_vocab()

    fn get_split_pattern(self)->String:
        return ""
    
    fn train(inout self, text:String,vocab_size:Int,verbose:Bool=False) raises ->None:
        if verbose:
            print("Training BasicTokenizationStrategy...")

        debug_assert(vocab_size >= 256,"vocab size too small (<256)")

        var num_merges = vocab_size - 256
        var ids = VocabManager.text_to_bytes(text)
        
        for idx in range(256):
            self.vocab_manager_ptr[].add_token(idx,chr(idx))
        
        for i in range(num_merges):
            var stats = CounterDict()
        
            var max_pair = MergeManager.update_stats_get_max(stats,ids)
            
            var idx = 256 + i 
            var merge_rule=MergeRule(max_pair,idx)
            
            MergeManager.merge(ids,merge_rule)
           
            self.merge_manager_ptr[].add_rule(merge_rule) 
            var new_vocab = self.vocab_manager_ptr[].add_token(merge_rule)

            if verbose:
                MergeManager.print_merge_round(i+1,num_merges,merge_rule,new_vocab,stats.get(max_pair,-1))
                

    fn encode(self, text:String)raises->List[Int]:   
        var ids = VocabManager.text_to_bytes(text)
        self.merge_manager_ptr[].apply_rules(ids)
        return ids       

    fn decode(self, ids:List[Int]) raises -> String:
        return self.vocab_manager_ptr[].get_tokens(ids)

    fn load(inout self, model_file:String) raises -> None:
        """Inverse of save() but only for the model file."""

        # read the model file
        with open(model_file, 'r') as f:
            var lines = f.read().split("\n")
            # check version
            debug_assert(lines[0].strip() == "minbpe v1","wrong model version: " +lines[0].strip() )
            # no pattern (empty line)
            # no special tokens (0 line)
            var idx = 256
            for line_number in range(3,len(lines)):
                if len(lines[line_number].strip()) == 0:
                    continue
                var t = lines[line_number].strip().split(" ")
                self.merge_manager_ptr[].add_rule(MergeRule(IDPair(t[0],t[1]),idx+line_number-3))

        

    fn save(self,model_file:String) raises -> None:
        
        with open(model_file, 'w') as f:
            # write the version, pattern and merges, that's all that's needed
            f.write("minbpe v1\n")
            f.write("\n") # no special pattern  
            f.write("0\n") # no special token
            
            for mr in self.merge_manager_ptr[].merge_rules:
                f.write(mr[].input_id_pair.get_model_string() + "\n")
                