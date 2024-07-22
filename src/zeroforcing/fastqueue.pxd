cdef class FastQueueForBFS:
    cdef:
        list array_list
        size_t max_possible_priority
        size_t smallest_nonempty_priority

        void push(self, size_t, object)
        object pop(self)
        tuple pop_and_get_priority(self)
