import itertools
import random
from sage.data_structures.bitset import Bitset, FrozenBitset


class FastQueueForBFS:
    
    def __init__(self, max_priority):
        self.array_list = []
        self.smallest_nonempty_priority = 0
        self.max_possible_priority = 0

        for i in range(max_priority+1):
            self.array_list.append( list([]) )
        self.max_possible_priority = max_priority
        self.smallest_nonempty_priority = max_priority + 1
    
    def __len__(self):
        total_length = 0
        for i in range(self.max_possible_priority+1):
            total_length += len(self.array_list[i])
        return total_length
    
    def pop(self):
        if self.smallest_nonempty_priority > self.max_possible_priority:
            return None
        else:
            item_to_return = self.array_list[self.smallest_nonempty_priority].pop()
        
        while self.smallest_nonempty_priority <= self.max_possible_priority:
            if len(self.array_list[self.smallest_nonempty_priority]) == 0:
                self.smallest_nonempty_priority += 1
            else:
                break
        return item_to_return
    
    def pop_and_get_priority(self):
        if self.smallest_nonempty_priority > self.max_possible_priority:
            return None
        else:
            item_to_return = self.array_list[self.smallest_nonempty_priority].pop()
            priority_to_return = self.smallest_nonempty_priority
        
        while self.smallest_nonempty_priority <= self.max_possible_priority:
            if len(self.array_list[self.smallest_nonempty_priority]) == 0:
                self.smallest_nonempty_priority += 1
            else:
                break
        return priority_to_return, item_to_return

    def push(self, priority_for_new_item, new_item):
        self.array_list[priority_for_new_item].append(new_item)
        
        if priority_for_new_item < self.smallest_nonempty_priority:
            self.smallest_nonempty_priority = priority_for_new_item





DijkstraMG = None

def shortest(v, path_so_far, predecessor_list, start):
    predecessor_of_v = predecessor_list[v]
    path_so_far.insert(0,predecessor_of_v)
    
    if predecessor_of_v[0] != start:
        shortest(predecessor_of_v[0], path_so_far, predecessor_list, start)
    return path_so_far

def build_zf_set(final_metavx_list):
    global DijkstraMG #To access the graph's neighbors

    zf_set = set()

    for (filled_vertices, forcing_vx) in final_metavx_list[:-1]: #Do not need to do the last metavertex (everything is already filled)
        if forcing_vx not in filled_vertices: #If filled, don't need to add it to zf_set since it will already have been gotten for free
            zf_set.add(forcing_vx)
#        filled_set.add(forcing_vx) #Fill forcing vertex
        unfilled_neighbors = DijkstraMG.neighbors_dict[forcing_vx] - filled_vertices #Find n unfilled neighbors of forcing vertex
    
        if len(unfilled_neighbors)-1 > 0:
            zf_set.update(set(itertools.islice(unfilled_neighbors, len(unfilled_neighbors)-1))) #Pick n-1 of them, the last will be gotten for free
#        filled_set.update(DijkstraMG.neighbors_dict[forcing_vx]) #Fill all of the neighbors
    return zf_set

def dijkstra(metagraph, start, target):
    return real_dijkstra(metagraph, start, target)

cdef real_dijkstra(metagraph, start, target):
    global DijkstraMG
    DijkstraMG = metagraph

    #cdef Bitset previous_closure
    #cdef Bitset vx_and_neighbors
    
#    cdef frozenset current

    cdef dict previous
#    cdef list unvisited_queue
    
    cdef int current_distance
    cdef int cost_of_making_it_force
    cdef int what_forced
    cdef int new_dist
    
    cdef int num_vertices_primal_graph

    num_vertices_primal_graph = metagraph.num_vertices
    
#    current = FrozenBitset()
    
    previous = {}
#    unvisited_queue = [(0, start, None)]
    unvisited_queue = FastQueueForBFS(num_vertices_primal_graph)
    
    start_FrozenBitset = FrozenBitset(start, capacity=num_vertices_primal_graph)
    target_FrozenBitset = FrozenBitset(target, capacity=num_vertices_primal_graph)
    
    unvisited_queue.push( 0, (start_FrozenBitset, None) )
#    heapq.heapify(unvisited_queue)

    done = False
    while not done:
#        uv = heapq.heappop(unvisited_queue)
        current_distance, uv = unvisited_queue.pop_and_get_priority()
        
#        current_distance = uv[0]
        parent = uv[0]
        vx_that_is_to_force = uv[1]

        previous_closure = parent
#        test_capacity = max(parent)+1 if len(parent) > 0 else 1
#        previous_closure.update(Bitset(parent, capacity=test_capacity))

        vx_and_neighbors = Bitset()
        if vx_that_is_to_force != None:
            vx_and_neighbors.add(vx_that_is_to_force)
            vx_and_neighbors.update(metagraph.neighbors_dict[vx_that_is_to_force])
        current = metagraph.extend_closure(previous_closure, vx_and_neighbors)
        
        

        # whether vertex is in 'previous' is proxy for if it has been visited
        if current in previous:
            continue

#        superset_has_been_visited = False
#        for seen_set in previous:
#            if current.issubset(seen_set):
#                superset_has_been_visited = True
#                break
#        if superset_has_been_visited:
#            print "yay"
#            continue
            
            
        previous[current] = (parent, vx_that_is_to_force)

        if current == target_FrozenBitset: # We have found the target vertex, can stop searching now
            done = True
            break
            
        for neighbor_tuple in metagraph.neighbors_with_edges(current):
            what_forced = neighbor_tuple[1]
            cost_of_making_it_force = neighbor_tuple[0]
            
            new_dist = current_distance + cost_of_making_it_force
            
#            heapq.heappush(unvisited_queue, (new_dist, current, what_forced))
            unvisited_queue.push( new_dist, (current, what_forced) )

            
    temp = [(target_FrozenBitset, None)]
    shortest_path = shortest(target_FrozenBitset, temp, previous, start_FrozenBitset)

    print "Closures remaining on queue:                ", len(unvisited_queue)
    print "Length of shortest path found in metagraph: ", len(shortest_path)
#    print "Shortest path found: ", shortest_path

    
    return build_zf_set(shortest_path)