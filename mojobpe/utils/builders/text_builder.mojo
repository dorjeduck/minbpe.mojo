from .string_builder import StringBuilder
struct TextBuilder:
    var string_builder: List[StringBuilder]
    var number_of_strings: Int

    fn __init__(inout self, number_of_strings: Int,string_capacity:Int=64):
        self.string_builder = List[StringBuilder](capacity=number_of_strings)
        self.number_of_strings = number_of_strings
        
        for i in range(self.number_of_strings):
            self.string_builder.append(StringBuilder(capacity=string_capacity))

    fn __len__(self: Self) -> Int:
        var res = 0
        for i in range(self.number_of_strings):
            res += self.string_builder[i].array_builder.array_size
        return res

    @always_inline
    fn __str__(self: Self) -> String:
        var res = StringBuilder(capacity = len(self))
        for i in range(self.number_of_strings):
            res.add(self.string_builder[i])
        return res

    @always_inline
    fn __str2__(self: Self) -> String:
        var res:String = str(self.string_builder[0])
        for i in range(1,self.number_of_strings):
            res += str(self.string_builder[i])
        return res


