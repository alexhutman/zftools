cdef class FastQueueForBFS:
    cdef list array_list
    cdef int smallest_nonempty_priority
    cdef int max_possible_priority

    cdef pop(self)
    cdef tuple pop_and_get_priority(self)
    cdef push(self, int, tuple)
