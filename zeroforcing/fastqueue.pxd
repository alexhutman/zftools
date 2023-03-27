cdef extern from "limits.h":
    cdef unsigned int UINT_MAX

cdef class FastQueueForBFS:
    cdef:
        list array_list
        unsigned int max_possible_priority
        unsigned int smallest_nonempty_priority

        void push(self, unsigned int, object)
        object pop(self)
        tuple pop_and_get_priority(self)
