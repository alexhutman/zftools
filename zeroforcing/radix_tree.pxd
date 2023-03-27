from sage.data_structures.bitset cimport FrozenBitset
from sage.data_structures.bitset_base cimport bitset_t

cdef class RadixTreeNode:
    cdef:
        # TODO: Make getters/setters so these can't be directly modified
        public RadixTreeNode zero
        public RadixTreeNode one
        public RadixTreeNode prev
        public unsigned long value # START, 0, or 1
        public tuple context

        inline void set_zero(self)
        inline void set_one(self)
        inline void set_context(self, tuple)

        inline bint is_zero_node(self)
        inline bint is_start_node(self)

        inline bint is_zero_node_present(self)
        inline bint is_one_node_present(self)
        inline void set_zero_if_not_present(self)
        inline void set_one_if_not_present(self)

cdef class RadixTree:
    cdef:
        public RadixTreeNode start
        bitset_t cur_bitset

    cpdef bint is_subset(self, FrozenBitset)
    cpdef void insert(self, FrozenBitset, tuple context=*)
