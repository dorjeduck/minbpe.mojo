from utils.inlined_string import InlinedString

struct StringBuilder:
    var _data_ptr: DTypePointer[DType.int8]
    var allocated_bytes: Int
    var str_size:Int #length of String without terminating '0'
    

    fn __init__(inout self, allocated_bytes: Int = 64):
        self.allocated_bytes = allocated_bytes
        self._data_ptr = DTypePointer[DType.int8].alloc(self.allocated_bytes)
        self.str_size = 0

    fn __copyinit__(inout self, existing: Self):
        self.allocated_bytes = existing.allocated_bytes
        self._data_ptr = DTypePointer[DType.int8].alloc(self.allocated_bytes)
        memcpy(self._data_ptr, existing._data_ptr, self.allocated_bytes)
        self.str_size = existing.str_size

    fn __moveinit__(inout self, owned existing: Self):
        self.allocated_bytes = existing.allocated_bytes
        self._data_ptr = existing._data_ptr
        self.str_size = existing.str_size

    fn __del__(owned self):
        self._data_ptr.free()

    #@always_inline  
    #fn append(inout self, val: String):
    #    self.add(val._buffer.data)

    @always_inline
    fn add(inout self,value:String):
        self.add(InlinedString(value))

    @always_inline
    fn add(inout self,value:StringLiteral):
        self.add_buffer(value.data(),len(value))
    
    @always_inline
    fn add(inout self,value:InlinedString):
        self.add_buffer(value.as_ptr(),len(value))
    
    @always_inline  
    fn add[T: DType, size: Int](inout self, value: SIMD[T, size]):
        var prev_end = 0
        var str_length = size * T.sizeof()
        var old_str_size = self.str_size
        self.str_size += str_length
        
        var needs_realocation = False
        while self.str_size > self.allocated_bytes-1:
            self.allocated_bytes += self.allocated_bytes >> 1
            needs_realocation = True

        if needs_realocation:
            var str = DTypePointer[DType.int8].alloc(self.allocated_bytes)
            memcpy(str, self._data_ptr, old_str_size)
            self._data_ptr.free()
            self._data_ptr = str
        
        self._data_ptr.store(old_str_size, bitcast[DType.int8, size * T.sizeof()](value))
    
    @always_inline
    fn add_buffer[T: DType](inout self, pointer: DTypePointer[T], size: Int):
        var str_length = size * T.sizeof()
        var old_str_size = self.str_size
        self.str_size += str_length
        
        var needs_realocation = False
        while self.str_size > self.allocated_bytes:
            self.allocated_bytes += self.allocated_bytes >> 1
            needs_realocation = True

        if needs_realocation:
            var str = DTypePointer[DType.int8].alloc(self.allocated_bytes)
            memcpy(str, self._data_ptr, old_str_size)
            self._data_ptr.free()
            self._data_ptr = str
        
        memcpy(self._data_ptr.offset(old_str_size), pointer.bitcast[DType.int8](), str_length)

    @always_inline
    fn __str__(self: Self) -> String:
        self._data_ptr.store(self.str_size, 0) # Null terminate the string
        return StringRef(self._data_ptr,self.str_size+1)
   
    @always_inline
    fn reset(inout self):
        self.str_size = 0