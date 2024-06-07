from utils.inlined_string import InlinedString

from .array_builder import ArrayBuilder

struct StringBuilder:
    var array_builder:ArrayBuilder[DType.int8]

    fn __init__(inout self,capacity: Int = 64):
        self.array_builder = ArrayBuilder[DType.int8](capacity=capacity)
    
    @always_inline
    fn add(inout self, value: String):  
        self.add_inlined_str(InlinedString(value))

    @always_inline
    fn add_inlined_str(inout self, value: InlinedString):
        self.array_builder.add_buffer(value.as_ptr(), len(value))

    @always_inline
    fn add_string_literal(inout self, inout value: StringLiteral):
        self.array_builder.add_buffer(value.data(), len(value))

    fn __copyinit__(inout self, existing: Self):
        self.array_builder.__copyinit__(existing.array_builder)

    fn __moveinit__(inout self, owned existing: Self):
        self.array_builder.__moveinit__(existing.array_builder)

    @always_inline
    fn __str__(self: Self) -> String:
        return StringRef(self.array_builder.array_ptr, self.array_builder.array_size)

