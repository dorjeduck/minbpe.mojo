from sys import exit 
from time import now

struct MoText[MEM_AHEAD_FACTOR:Int = 2]:
    var mostrings: List[MoString[MEM_AHEAD_FACTOR]]
    var number_of_mostrings:Int

    fn __init__(inout self, number_of_mostrings: Int,mostring_capacity:Int=64):
        self.mostrings = List[MoString[MEM_AHEAD_FACTOR]](capacity=number_of_mostrings)
        self.number_of_mostrings = number_of_mostrings
       
        for i in range(self.number_of_mostrings):
            self.mostrings.append(MoString[MEM_AHEAD_FACTOR](capacity=mostring_capacity))

    fn append(inout self,idx:Int,str:String):
        self.mostrings[idx]+=str
    
    @always_inline
    fn __len__(self: Self) -> Int:
        var res = 0
        for i in range(self.number_of_mostrings):
            res += len(self.mostrings[i].string)
        return res


    @always_inline
    fn __str__(self: Self) -> String:
        var res = MoString(capacity = len(self)+1)
        for i in range(self.number_of_mostrings):
            res+=self.mostrings[i].string
        return str(res)



