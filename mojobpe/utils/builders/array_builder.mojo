struct ArrayBuilder[T:DType]:
    var array_ptr: DTypePointer[T]
    var allocated_size: Int
    var array_size: Int  # length of String without terminating '0'

    fn __init__(inout self, capacity: Int = 64):
        self.allocated_size = capacity
        self.array_ptr = DTypePointer[T].alloc(self.allocated_size)
        self.array_size = 0

    fn __copyinit__(inout self, existing: Self):
        self.allocated_size = existing.allocated_size
        self.array_ptr = DTypePointer[T].alloc(self.allocated_size)
        memcpy(self.array_ptr, existing.array_ptr, self.allocated_size)
        self.array_size = existing.array_size

    fn __moveinit__(inout self, owned existing: Self):
        self.allocated_size = existing.allocated_size
        self.array_ptr = existing.array_ptr
        self.array_size = existing.array_size

    fn __del__(owned self):
        self.array_ptr.free()

    @always_inline
    fn add(inout self, other: Self):
        self.add_buffer(other.array_ptr, other.array_size)

    @always_inline
    fn add[size: Int](inout self, value: SIMD[T, size]):
        var prev_end = 0
        var additional_size = size * T.sizeof()
        
        var old_array_size = self.array_size
        self.array_size += additional_size

        var needs_realocation = False
        while self.array_size > self.allocated_size:
            self.allocated_size += self.allocated_size >> 1
            needs_realocation = True

        if needs_realocation:
            var str = DTypePointer[T].alloc(self.allocated_size)
            memcpy(str, self.array_ptr, old_array_size)
            self.array_ptr.free()
            self.array_ptr = str

        self.array_ptr.store(
            old_array_size, value
        )

    @always_inline
    fn add_buffer(inout self, pointer: DTypePointer[T], size: Int):
        var str_length = size * T.sizeof()
        var old_array_size = self.array_size
        self.array_size += str_length

        var needs_realocation = False
        while self.array_size > self.allocated_size:
            self.allocated_size += self.allocated_size >> 1
            needs_realocation = True

        if needs_realocation:
            var str = DTypePointer[T].alloc(self.allocated_size)
            memcpy(str, self.array_ptr, old_array_size)
            self.array_ptr.free()
            self.array_ptr = str

        memcpy(
            self.array_ptr.offset(old_array_size),
            pointer,
            str_length,
        )

    @always_inline
    fn reset(inout self):
        self.array_size = 0

