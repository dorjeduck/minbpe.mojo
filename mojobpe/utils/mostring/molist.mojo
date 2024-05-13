from memory.unsafe_pointer import move_pointee

struct MoList[T:CollectionElement](CollectionElement):
    var list:List[T]
    fn __init__(inout self,capacity:Int = 1):

        """Construct a MoString from a StringRef object.

        Args:
            capacity: The requested initial memory capacity.
        """
        self.list = List[T]()
        if capacity>1 :
            self.list._realloc(capacity)


    @always_inline
    fn extend(inout self, owned other: List[T]):
        """Extends this list by consuming the elements of `other`.

        Args:
            other: List whose elements will be added in order at the end of this list.
        """

        var final_size = len(self.list) + len(other)
        var other_original_size = len(other)

        # realloc instead of reserve
        if self.list.capacity == 0:
            if len(other)>0:
                self.list._realloc(len(other))
        else:   
            var cap = self.list.capacity
            var realloc = False
            while cap < final_size :
                cap *= 2
                realloc = True
            if realloc:
                self.list._realloc(cap)
                
        # Defensively mark `other` as logically being empty, as we will be doing
        # consuming moves out of `other`, and so we want to avoid leaving `other`
        # in a partially valid state where some elements have been consumed
        # but are still part of the valid `size` of the list.
        #
        # That invalid intermediate state of `other` could potentially be
        # visible outside this function if a `__moveinit__()` constructor were
        # to throw (not currently possible AFAIK though) part way through the
        # logic below.
        other.size = 0

        var dest_ptr = self.list.data + len(self.list)

        for i in range(other_original_size):
            var src_ptr = other.data + i

            # This (TODO: optimistically) moves an element directly from the
            # `other` list into this list using a single `T.__moveinit()__`
            # call, without moving into an intermediate temporary value
            # (avoiding an extra redundant move constructor call).
            move_pointee(src=src_ptr, dst=dest_ptr)

            dest_ptr = dest_ptr + 1

        # Update the size now that all new elements have been moved into this
        # list.
        self.list.size = final_size

    fn optimize_memory(inout self):
        if self.list.size < self.list.capacity:
            self.list._realloc(self.list.size)

    fn info(self,include_string:Bool=True) -> String:
        var res:String = ""
        res += "(Size: " + str(self.list.size-1) + '+1'  + ", Capacity: " + str(self.list.capacity) + ")"
        return res

    @always_inline
    fn __copyinit__(inout self, existing: Self):
        """Creates a deep copy of an existing MoString.

        Args:
            existing: The MoString to copy.
        """
        # Todo: make sure this works
        self.list.__copyinit__(existing.list) 
    
    @always_inline
    fn __moveinit__(inout self, owned existing: Self):
        """Move the value of a MoString.

        Args:
            existing: The MoString to move.
        """
        # Todo: make sure this works
        self.list.__moveinit__(existing.list) 


