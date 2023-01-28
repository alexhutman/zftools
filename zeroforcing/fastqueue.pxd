cdef extern from "limits.h":
    cdef unsigned int UINT_MAX

cdef class FastQueueForBFS:
    cdef list array_list
    cdef unsigned int length
    cdef unsigned int max_possible_priority
    cdef unsigned int smallest_nonempty_priority

    cdef void push(self, unsigned int, object)
    cdef object pop(self)
    cdef tuple pop_and_get_priority(self)
