from .string_builder import StringBuilder

struct TextBuilder:
    var ptr: UnsafePointer[StringBuilder]
    var size: Int

    fn __init__(inout self, size: Int):
        self.ptr = UnsafePointer[StringBuilder].alloc(size)
        self.size = size
        for i in range(self.size):
            self.ptr[i] = StringBuilder()

    fn __del__(owned self):
        for i in range(self.size):
            destroy_pointee(self.ptr + i)
        self.ptr.free()

    fn __getitem__(self: Self, index: Int) -> StringBuilder:
        return self.ptr[index]

    fn __len__(self: Self) -> Int:
        var res = 0
        for i in range(self.size):
            res += self.ptr[i].str_size
        return res

    fn add(self, index: Int, val: String):
        self.ptr[index].add(val)

    @always_inline
    fn slow__str__(self: Self) -> String:
        var text = StringBuilder(self.__len__() + 1)
        for i in range(self.size):
            text.add(self.ptr[i])
        return str(text)

    @always_inline
    fn __str__(self: Self) -> String:
        var res:String = str(self.ptr[0])
        for i in range(1,self.size):
            res += str(self.ptr[i])
        return res
    
    @always_inline
    fn unsafe__str__(self: Self) -> String:
       
        var ptr = DTypePointer[DType.int8].alloc(len(self)+1)
        var offset = 0
        for i in range(self.size):
            memcpy(ptr+offset,self.ptr[i]._data_ptr,self.ptr[i].str_size)
            offset += self.ptr[i].str_size
        
        return StringRef(ptr, offset)