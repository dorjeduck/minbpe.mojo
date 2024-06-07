from algorithm import parallelize
from collections.vector import InlinedFixedVector
from python import Python

from .merge_manager import MergeManager
from .mostring import MoString, MoText
from .string_dict import Dict as StringDict
from .generic_dict import Dict as GenericDict,Keyable,KeyElement,KeysBuilder
from .tat import distribute_jobs, print_list_int, IntKey

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
    var vocab: GenericDict[String]
    var special_tokens: StringDict[String]
    var inverse_special_tokens: GenericDict[String]
    var regex: PythonObject

    var special_token_list: List[TokenData]

    fn __init__(inout self) raises:
        self.vocab = GenericDict[String](capacity=64)
        self.special_tokens = StringDict[String]()

        self.special_token_list = List[TokenData]()

        self.inverse_special_tokens = GenericDict[String](capacity=64)
        self.regex = Python.import_module("regex")
        self.build_vocab()

    fn clear(inout self):
    
        self.vocab.clear()
        self.special_tokens.clear()
        self.inverse_special_tokens.clear()
        self.special_token_list.clear()

    
    fn add_token(inout self,mr:MergeRule) raises -> String:

        var new_vocab = self.get_token(int(mr.input_id_pair.data[0])) +
                        self.get_token(int(mr.input_id_pair.data[1])) 
        self.add_token(mr.merge_id,new_vocab)

        return new_vocab

    
    @always_inline("nodebug")
    fn add_token(inout self, idx: Int, token: String) raises -> None:
        _ = self.vocab.put(IntKey(idx), token)

    @always_inline("nodebug")
    fn get_token(inout self, idx: Int, include_special: Bool = False)  raises -> String:
        #try:
        var res = self.vocab.get(IntKey(idx), "")
        if include_special and len(res) == 0:
            res = self.get_special_token(idx)
        return res
        #except:
        #    print("problem getting token for id",idx)
        #    return ""

    @always_inline("nodebug")
    fn get_tokens_simple(
        inout self, ids: List[Int], include_special: Bool = False
    ) raises -> MoString:
        var res = MoString(capacity=len(ids)*5)
        for i in range(len(ids)):
            res+=self.get_token(ids[i], include_special)

        #res.optimize_memory()
        return res^ 

    @always_inline("nodebug")
    fn get_tokens(
        inout self, ids: List[Int], include_special: Bool = False
    ) raises -> String:
        alias MAX_WORK_ITEMS = 10
        var n_jobs = len(ids)
        if n_jobs < 1000:
            return self.get_tokens_simple(ids, include_special)
        else:
            
            var num_work_items = min(MAX_WORK_ITEMS, n_jobs // 100)
            var dj = distribute_jobs(n_jobs, num_work_items)
            
            var tb = MoText(num_work_items)        
            @parameter
            fn _calc(ip: Int):
                for i in range(dj[ip], dj[ip + 1]):
                    try:
                        tb.append(ip,self.get_token(ids[i], include_special))
                    except:
                        pass      
        
            parallelize[_calc](num_work_items)
        
            _ = dj[0]  # dj lifetime insurance ....
            
            return str(tb)

    fn build_vocab(inout self) raises -> None:  # , special_tokens):
        # Initialize with single-byte tokens.
        for idx in range(256):
            _ = self.vocab.put(IntKey(idx), chr(idx))

    fn register_special_tokens(inout self, special_tokens_str: String) raises:
        var compiled_pattern = self.regex.compile(SPECIAL_TOKENS_PATTERN)

        var special_tokens = self.regex.findall(
            compiled_pattern, special_tokens_str
        )

        for st in special_tokens:
            self.register_special_token(TokenData(str(st[1]), atol(str(st[2]))))

    fn register_special_token(inout self, st: TokenData) raises:
        self.special_tokens.put(st.token, str(st.id))
        _ = self.inverse_special_tokens.put(IntKey(st.id), st.token)
        self.special_token_list.append(st)

    fn split_by_special_tokens(self, text: String) raises -> List[String]:
        if len(self.special_token_list) == 0:
            return List[String](text)

        var special_pattern = String("(")

        for i in range(len(self.special_token_list) - 1):
            special_pattern += (
                str(self.regex.escape(self.special_token_list[i].token)) + "|"
            )
        special_pattern += (
            str(self.regex.escape(self.special_token_list[-1].token)) + ")"
        )

        var compiled_pattern = self.regex.compile(special_pattern)

        var special_chunks = self.regex.split(compiled_pattern, text)

        var res = List[String]()

        for sc in special_chunks:
            res.append(str(sc))
        return res

    @always_inline("nodebug")
    fn get_special_token_id(self, text: String) raises -> Int:
        return atol(self.special_tokens.get(text, "-1"))

    @always_inline("nodebug")
    fn get_special_token(inout self, id: Int) raises -> String:
        return self.inverse_special_tokens.get(IntKey(id), "")

    @always_inline("nodebug")
    fn check_special_token_in_text(self, text: String) -> Bool:
        for st in self.special_token_list:
            if st[].token in text:
                return True
        return False

    @staticmethod
    @always_inline("nodebug")
    fn text_to_bytes(text: String) -> List[Int]:
        var ids = List[Int](capacity=len(text))
        for i in range(len(text)):
            ids.append(ord(text[i]))
        return ids

    @staticmethod
    @always_inline("nodebug")
    fn text_to_bytes(text: String,inout ids:List[Int]) :
        for i in range(len(text)):
            ids.append(ord(text[i]))
       

