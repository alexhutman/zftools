import heapq

# Disabling bounds checking in this class sounds like it would be perfect here(?)
cdef class FastQueueForBFS:
    def __init__(self, max_priority):
        self.length = 0
        self.heapqueue = list()
        self.heapqueue_elements = {i: list() for i in range(max_priority+1)}

    def __len__(self):
        return self.length

    cdef void push(self, unsigned int priority_for_new_item, object new_item):
        # Check for negative here?
        # raise ValueError if priority_for_new_item > self.max_possible_priority?
            # Not checking makes it faster though :)

        if len(self.heapqueue_elements[priority_for_new_item]) == 0:
            heapq.heappush(self.heapqueue, priority_for_new_item)
        self.heapqueue_elements[priority_for_new_item].append(new_item)
        self.length += 1

    cdef object pop(self):
        cdef unsigned int _
        cdef object popped

        _, popped = self.pop_and_get_priority()
        return popped

    cdef tuple pop_and_get_priority(self):
        # Store vals to return
        cdef unsigned int priority_to_return = heapq.heappop(self.heapqueue)
        cdef object item_to_return = self.heapqueue_elements[priority_to_return].pop()
        self.length -= 1

        return priority_to_return, item_to_return
