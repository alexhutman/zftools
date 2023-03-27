from sage.data_structures.bitset cimport FrozenBitset
from sage.data_structures.bitset_base cimport (
    bitset_copy_flex,
    bitset_free,
    bitset_in,
    bitset_init,
    bitset_isempty,
    bitset_rshift,
    bitset_t,
)
from sage.libs.gmp.types cimport mp_bitcnt_t


cdef extern from *:
    # Is there an easier way to define constants...?
    """
    #define MG_METAVERTEX_FIRST_VX 0
    #define MG_RADIX_TREE_SHIFT_ONE 1

    #define MG_RADIX_TREE_ZERO 0
    #define MG_RADIX_TREE_ONE 1
    """
    const unsigned long MG_METAVERTEX_FIRST_VX
    const mp_bitcnt_t MG_RADIX_TREE_SHIFT_ONE

    const unsigned long MG_RADIX_TREE_ZERO
    const unsigned long MG_RADIX_TREE_ONE

cdef extern from "<limits.h>":
    """
    #define MG_RADIX_TREE_START ULONG_MAX
    """
    const unsigned long MG_RADIX_TREE_START


cdef class RadixTreeNode:
    def __init__(self, unsigned long value):
        self.value = value

    cdef inline void set_zero(self):
        self.zero = RadixTreeNode(MG_RADIX_TREE_ZERO)
        self.zero.prev = self

    cdef inline void set_one(self):
        self.one = RadixTreeNode(MG_RADIX_TREE_ONE)
        self.one.prev = self

    cdef inline void set_context(self, tuple context):
        self.context = context

    cdef inline bint is_zero_node(self):
        return self.value == MG_RADIX_TREE_ZERO

    cdef inline bint is_start_node(self):
        return self.value == MG_RADIX_TREE_START

    cdef inline bint is_zero_node_present(self):
        return self.zero is not None

    cdef inline bint is_one_node_present(self):
        return self.one is not None

    cdef inline void set_zero_if_not_present(self):
        if not self.is_zero_node_present():
            self.set_zero()

    cdef inline void set_one_if_not_present(self):
        if not self.is_one_node_present():
            self.set_one()

cdef class RadixTree:
    """
    Construct RadixTree from least -> most significant bits of
    the bitset_t contained in the metavertex.

    E.g. Inserting Metavertex = FrozenBitset({1,2,4}) = 10110 yields:
    (start) -> (0) -> (1) -> (1) -> (0) -> (1)

    Inserting Metavertex = FrozenBitset({1,3,5}) = 101010 afterwards yields:
                            (0) -> (1) -> (0) -> (1)
    (start) -> (0) -> (1) 〈
                            (1) -> (0) -> (1)

    The copies in is_subset() and insert() require that capacity(metavertex) <= capacity(self.cur_bitset)

    In our case, the upper bound of vertices contained in each metavertex = |G|, meaning the RadixTree will be initialized with a capacity of |G|, i.e. this is always true.
    """
    def __cinit__(self, mp_bitcnt_t size):
        bitset_init(self.cur_bitset, size)
        self.start = RadixTreeNode(MG_RADIX_TREE_START)

    def __dealloc__(self):
        bitset_free(self.cur_bitset)

    cpdef bint is_subset(self, FrozenBitset metavertex):
        bitset_copy_flex(self.cur_bitset, metavertex._bitset)
        cdef:
            RadixTreeNode cur = self.start
            bint is_candidate_in_metavx = bitset_in(self.cur_bitset, MG_METAVERTEX_FIRST_VX)
            bint zero_present
            bint one_present
            list stack = [cur]

        while not bitset_isempty(self.cur_bitset) and len(stack) > 0:
            cur = stack.pop()
            zero_present = cur.is_zero_node_present()
            one_present = cur.is_one_node_present()

            if is_candidate_in_metavx:
                if one_present:
                    stack.append(cur.one)
                else:
                    return False
            else:
                if not (zero_present or one_present):
                    return False
                if zero_present:
                    stack.append(cur.zero)
                if one_present:
                    stack.append(cur.one)

            # Hopefully shifting and storing in the same bitset_t is okay...
            bitset_rshift(self.cur_bitset, self.cur_bitset, MG_RADIX_TREE_SHIFT_ONE) # Pop metavertex (bitset) bits in order of LSB -> MSB
            is_candidate_in_metavx = bitset_in(self.cur_bitset, MG_METAVERTEX_FIRST_VX)
        return True

    cpdef void insert(self, FrozenBitset metavertex, tuple context=None):
        """
        We reuse nodes if applicable. E.g. inserting {2} = 001 yields:
        (start) -> (0) -> (0) -> (1)

        If we then insert {1,2} = 011:
                          (0)
        (start) -> (0) 〈     〉 (1)
                          (1)
        """
        bitset_copy_flex(self.cur_bitset, metavertex._bitset)
        cdef:
            # TODO: Better variable names
            RadixTreeNode cur = self.start
            RadixTreeNode prev = None
            RadixTreeNode prev_other = None
            RadixTreeNode prev_other_next = None
            bint is_candidate_in_metavx = bitset_in(self.cur_bitset, MG_METAVERTEX_FIRST_VX)

        while not bitset_isempty(self.cur_bitset):
            # TODO: Pull this block out above since we'll always start at the start node for inserts. Also clean up the logic.
            if cur.is_start_node():
                if is_candidate_in_metavx:
                    if not cur.is_one_node_present():
                        cur.set_one_if_not_present()
                    cur = cur.one
                else:
                    if not cur.is_zero_node_present():
                        cur.set_zero_if_not_present()
                    cur = cur.zero

                bitset_rshift(self.cur_bitset, self.cur_bitset, MG_RADIX_TREE_SHIFT_ONE)
                is_candidate_in_metavx = bitset_in(self.cur_bitset, MG_METAVERTEX_FIRST_VX)
                continue

            prev = cur.prev
            prev_other = prev.one if cur.is_zero_node() else prev.zero
            if is_candidate_in_metavx:
                prev_other_next = None if prev_other is None else prev_other.one
                if prev_other_next is not None:
                    # Reuse node
                    cur.one = prev_other_next
                else:
                    cur.set_one_if_not_present()
                cur = cur.one
            else:
                prev_other_next = None if prev_other is None else prev_other.zero
                if prev_other_next is not None:
                    # Reuse node
                    cur.zero = prev_other_next
                else:
                    cur.set_zero_if_not_present()
                cur = cur.zero

            # Hopefully shifting and storing in the same bitset_t is okay...
            bitset_rshift(self.cur_bitset, self.cur_bitset, MG_RADIX_TREE_SHIFT_ONE) # Pop metavertex (bitset) bits in order of LSB -> MSB
            is_candidate_in_metavx = bitset_in(self.cur_bitset, MG_METAVERTEX_FIRST_VX)

        cur.set_context(context)
