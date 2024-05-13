from algorithm import parallelize
from python import Python
from time import now

from .utils import IDPair, MergeManager,MergeRule,VocabManager,TokenData
from .utils.generic_dict import CounterDict
from .utils.tat import MoBench
from .standards import GPT2_SPLIT_PATTERN,GPT4_SPLIT_PATTERN
from .tokenizer import TokenizationStrategy
from .utils.mostring import MoList


struct RegexTokenizationStrategy[PATTERN:String=GPT4_SPLIT_PATTERN,ALLOWED_SPECIAL:String="all"](TokenizationStrategy):
   
    var merge_manager_ptr:Pointer[MergeManager]
    var vocab_manager_ptr:Pointer[VocabManager]

    var pattern:String

    var regex:PythonObject
    
    var compiled_pattern:PythonObject

    fn __init__(inout self) raises:
        
        self.regex = Python.import_module("regex")
        self.pattern = PATTERN
        self.compiled_pattern = self.regex.compile(PATTERN)

        self.merge_manager_ptr = Pointer[MergeManager]()
        self.vocab_manager_ptr = Pointer[VocabManager]()

    fn set(inout self,merge_manager_ptr:Pointer[MergeManager],vocab_manager_ptr:Pointer[VocabManager]):
        self.merge_manager_ptr = merge_manager_ptr
        self.vocab_manager_ptr = vocab_manager_ptr

    fn clear(inout self) raises:
        self.pattern = ""
        self.compiled_pattern = PythonObject()
        self.merge_manager_ptr[].clear()
        self.vocab_manager_ptr[].clear()
        self.vocab_manager_ptr[].build_vocab()

    fn set_pattern(inout self,pattern:String) raises -> None:
        self.pattern = pattern
        self.compiled_pattern = self.regex.compile(PATTERN)
   
    fn get_split_pattern(self)->String:
        return self.pattern

    fn train(inout self,text:String,vocab_size:Int,verbose:Bool=True) raises -> None:
        if verbose:
            print("Training RegexTokenizationStrategy...")

        debug_assert(vocab_size >= 256,"vocab size too small (<256)")

        var num_merges = vocab_size - 256

        # split the text up into text chunks
        var text_chunks = self.regex.findall(self.compiled_pattern, text)
        var num_chunks = len(text_chunks)
       
        var ids = List[List[Int]](capacity=num_chunks)
        
        for tc in text_chunks:
            ids.append(VocabManager.text_to_bytes(tc))
        
        for idx in range(256):
            self.vocab_manager_ptr[].add_token(idx,chr(idx))
    
        for i in range(num_merges):
        
            var stats = CounterDict()
            var unique_id_pairs = List[IDPair]()
            
            for chunk_ids in ids:
                if len(chunk_ids[])>1:
                    MergeManager.update_stats_and_keys(stats,unique_id_pairs,chunk_ids[])
                
            var max_pair = unique_id_pairs[0]
            var max_val = stats.get(max_pair,-1)
            
            for j in range(1,len(unique_id_pairs)):
                var val = stats.get(unique_id_pairs[j],-1)
                if val > max_val:
                    max_val=val
                    max_pair = unique_id_pairs[j]

            var idx = 256 + i 
            var merge_rule=MergeRule(max_pair,idx)
           
            for chunk_ids in ids:
                MergeManager.merge(chunk_ids[],merge_rule)

            self.merge_manager_ptr[].add_rule(merge_rule)  
            var new_vocab = self.vocab_manager_ptr[].add_token(merge_rule)

            if verbose:
                MergeManager.print_merge_round(i+1,num_merges,merge_rule,new_vocab,stats.get(max_pair,-1))
    
    fn _encode_ordinary(self, text:String)raises->List[Int]:
        var ids = VocabManager.text_to_bytes(text)
        self.merge_manager_ptr[].apply_rules(ids)
        return ids  

    fn encode_ordinary(self, text:String) raises->List[Int]:
        """Encoding that ignores any special tokens."""
        
        # split text into chunks of text by categories defined in regex pattern
        var text_chunks = self.regex.findall(self.compiled_pattern, text)
        
        
        var ids = List[Int]()
       
        # all chunks of text are encoded separately, then results are joined
       
        for tc in text_chunks:
            var chunk_ids = VocabManager.text_to_bytes(tc)
            if len(chunk_ids)>1: 
                self.merge_manager_ptr[].apply_rules(chunk_ids)
            for ci in chunk_ids:      
                ids.append(ci[])
        
        return ids
    
    fn encode(self, text:String)raises->List[Int]:
        """
        Unlike encode_ordinary, this function handles special tokens.
        allowed_special: can be "all"|"none"|"none_raise" or a custom set of special tokens
        if none_raise, then an error is raised if any special token is encountered in text
        this is the default tiktoken behavior right now as well
        any other behavior is either annoying, or a major footgun.
        """
        # decode the user desire w.r.t. handling of special tokens
        var special:Bool 
        if ALLOWED_SPECIAL == "all":
            special = True
        elif ALLOWED_SPECIAL == "none":
            special = False
        elif ALLOWED_SPECIAL == "none_raise":
            if self.vocab_manager_ptr[].check_special_token_in_text(text):
                print("warning: special token in text")
            special = False
        #elif isinstance(allowed_special, set): Todo
        #    special = {k: v for k, v in self.special_tokens.items() if k in allowed_special}
        else:
            ##print ValueError(f"allowed_special={allowed_special} not understood")
            print("warning: " + str(ALLOWED_SPECIAL) + " not understood, set to none")
            special = False
        if not special:
            # shortcut: if no special tokens, just use the ordinary encoding
            return self.encode_ordinary(text)
        
        # otherwise, we have to be careful with potential special tokens in text
        # we handle special tokens by splitting the text
        # based on the occurrence of any exact match with any of the special tokens
        # we can use re.split for this. note that surrounding the pattern with ()
        # makes it into a capturing group, so the special tokens will be included
       
        var special_chunks = self.vocab_manager_ptr[].split_by_special_tokens(text)
        
        # now all the special characters are separated from the rest of the text
        # all chunks of text are encoded separately, then results are joined
        
        var ids = List[Int]()
        for part in special_chunks:
           
            var id = self.vocab_manager_ptr[].get_special_token_id(part[])
            if id>=0:
                # this is a special token, encode it separately as a special case
                ids.append(id)
            else:
                # this is an ordinary sequence, encode it normally
                ids.extend(self.encode_ordinary(part[]))
        return ids

    fn decode(self, ids:List[Int]) raises -> String:
        return self.vocab_manager_ptr[].get_tokens(ids,True)

    fn load(inout self, model_file:String) raises -> None:
        """Inverse of save() but only for the model file."""      
        
        with open(model_file, 'r') as f:

            var lines = f.read().split("\n")        
            # check version
            debug_assert(lines[0].strip() == "minbpe v1","wrong model version: " +lines[0].strip() )
            # add pattern
            self.pattern = lines[1].strip()
            self.compiled_pattern = self.regex.compile(self.pattern)

            # read the special tokens
            var num_special = int(lines[2].strip())
            for line_number in range(3,3+num_special):
                var t = lines[line_number].strip().split(" ")
                self.vocab_manager_ptr[].register_special_token(TokenData(t[0],atol(t[1])))
                         
            var idx = 256
            for line_number in range(3+num_special,len(lines)):      
                if len(lines[line_number].strip()) == 0:
                    continue
                var t = lines[line_number].strip().split(" ")
                self.merge_manager_ptr[].add_rule(MergeRule(IDPair(t[0],t[1]),idx+line_number-num_special-3))

                
    fn save(self,model_file:String) raises -> None:
        
        
        with open(model_file, 'w') as f:
            # write the version, pattern and merges, that's all that's needed
            f.write("minbpe v1\n")

            f.write(PATTERN + "\n")
            
            var len_special_tokens = len(self.vocab_manager_ptr[].special_token_list)

            f.write(str(len_special_tokens) + "\n")

            for st in self.vocab_manager_ptr[].special_token_list:
                f.write(st[].get_model_string() + "\n")
              
            for mr in self.merge_manager_ptr[].merge_rules:
                f.write(mr[].input_id_pair.get_model_string() + "\n")
                   
    