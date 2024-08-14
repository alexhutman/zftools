cdef extern from "stdint.h":
    cdef size_t SIZE_MAX

# Disabling bounds checking in this class sounds like it would be perfect here(?)
cdef class FastQueueForBFS:
    def __init__(self, max_priority):
        self.max_possible_priority = max_priority
        self.smallest_nonempty_priority = SIZE_MAX

        self.array_list = [list() for _ in range(max_priority+1)]

    cdef void push(self, size_t priority_for_new_item, object new_item):
        # Check for negative here?
        # raise ValueError if priority_for_new_item > self.max_possible_priority?
        # Not checking makes it faster though :)

        self.array_list[priority_for_new_item].append(new_item)

        self.smallest_nonempty_priority = min(
                priority_for_new_item,
                self.smallest_nonempty_priority)

    cdef object pop(self):
        cdef size_t _
        cdef object popped

        _, popped = self.pop_and_get_priority()
        return popped

    cdef tuple pop_and_get_priority(self):
        # Store vals to return
        cdef size_t priority_to_return = self.smallest_nonempty_priority
        cdef object item_to_return = self.array_list[priority_to_return].pop()

        # Find new smallest priority
        while (len(self.array_list[self.smallest_nonempty_priority]) == 0 and
               self.smallest_nonempty_priority < self.max_possible_priority):
            self.smallest_nonempty_priority += 1
        return priority_to_return, item_to_return
