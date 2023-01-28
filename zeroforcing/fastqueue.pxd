cdef extern from "limits.h":
    cdef unsigned int UINT_MAX

cdef class FastQueueForBFS:
    cdef list heapqueue
    cdef dict heapqueue_elements
    cdef unsigned int length

    cdef void push(self, unsigned int, object)
    cdef object pop(self)
    cdef tuple pop_and_get_priority(self)
