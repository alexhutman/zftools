#from sage.all import *
from sage.graphs.all import Graph

include "sage/data_structures/bitset.pxi"

include "cysignals/memory.pxi"

# Define metagraph class in Python
cdef class ZFSearchMetagraphNewAlg:
    cdef public int num_vertices, 
    cdef int num_vertices_checked, vertex_to_fill
    cdef bitset_t *neighborhood_array 
    cdef set vertices_set
    cdef public dict neighbors_dict
    
    #for-loop counters
    cdef int i, j, v, w, vertex, new_vx_to_make_force
    
    
    # Temp variable(s) for __init__ 
    
    # Initialize extend_closure variables
    cdef bitset_t filled_set, vertices_to_check, vertices_to_recheck, filled_neighbors, unfilled_neighbors, filled_neighbors_of_vx_to_fill
    
    # Initialize calculate_cost variables 
    cdef bitset_t meta_vertex
    cdef int numUnfilledNeighbors, accounter, cost
    
    
    def __cinit__(self, graph_for_zero_forcing):
        self.num_vertices = graph_for_zero_forcing.num_verts()
        self.neighborhood_array = <bitset_t*> sig_malloc(self.num_vertices*sizeof(bitset_t)) #ALLOCATE NEIGHBORHOOD_ARRAY
        
        
        # Initialize/clear extend_closure bitsets
        bitset_init(self.filled_set, self.num_vertices)
        bitset_init(self.vertices_to_check, self.num_vertices)
        bitset_init(self.vertices_to_recheck, self.num_vertices)
        bitset_init(self.filled_neighbors, self.num_vertices)
        bitset_init(self.unfilled_neighbors, self.num_vertices)
        bitset_init(self.filled_neighbors_of_vx_to_fill, self.num_vertices)
        bitset_init(self.meta_vertex, self.num_vertices)
    
    def __init__(self, graph_for_zero_forcing):
        self.vertices_set = set(graph_for_zero_forcing.vertices())
        
        
        self.neighbors_dict = {} #TODO: Only so Dijkstra code doesn't break. Ideally want to remove this somehow
        for i in graph_for_zero_forcing.vertices():
            temp_vertex_neighbors = FrozenBitset(graph_for_zero_forcing.neighbors(i))
            self.neighbors_dict[i] = temp_vertex_neighbors
            
        # create pointer to bitset array with neighborhoods
        for v in range(self.num_vertices):
            bitset_init(self.neighborhood_array[v], self.num_vertices)
            bitset_clear(self.neighborhood_array[v])
            for w in graph_for_zero_forcing.neighbors(v):
                bitset_add(self.neighborhood_array[v], w)   
        
        #The variable below is just for profiling purposes!
        self.num_vertices_checked = 0
        
    def __dealloc__(self):
        sig_free(self.neighborhood_array) #DEALLOCATE NEIGHBORHOOD_ARRAY
        
        bitset_free(self.filled_set)
        bitset_free(self.vertices_to_check)
        bitset_free(self.vertices_to_recheck)
        bitset_free(self.filled_neighbors)
        bitset_free(self.unfilled_neighbors)
        bitset_free(self.filled_neighbors_of_vx_to_fill)
        bitset_free(self.meta_vertex)
    
    
    cdef FrozenBitset extend_closure(self, FrozenBitset initially_filled_subset2, FrozenBitset vxs_to_add2):
        
        cdef bitset_t initially_filled_subset
        cdef bitset_t vxs_to_add
        
        bitset_init(initially_filled_subset, self.num_vertices)
        bitset_init(vxs_to_add, self.num_vertices)

        ##################################### THIS SEEMS TO WORK! #####################################
        bitset_copy(initially_filled_subset, &initially_filled_subset2._bitset[0])
        bitset_copy(vxs_to_add, &vxs_to_add2._bitset[0])
        
        bitset_clear(self.filled_set)
        bitset_clear(self.vertices_to_check)
        bitset_clear(self.vertices_to_recheck)
        bitset_clear(self.filled_neighbors)
        bitset_clear(self.unfilled_neighbors)
        bitset_clear(self.filled_neighbors_of_vx_to_fill)
        
        bitset_union(self.filled_set, initially_filled_subset, vxs_to_add)

        bitset_copy(self.vertices_to_check, vxs_to_add)

        for v in range(self.num_vertices):
            if bitset_in(vxs_to_add, v):
                bitset_intersection(self.filled_neighbors, self.neighborhood_array[v], self.filled_set)
                bitset_union(self.vertices_to_check, self.vertices_to_check, self.filled_neighbors)
            
        bitset_clear(self.vertices_to_recheck)
        while not bitset_isempty(self.vertices_to_check):
            #print "now will check", vertices_to_check
            bitset_clear(self.vertices_to_recheck)
            for vertex in range(self.num_vertices):
                if bitset_in(self.vertices_to_check, vertex):
                    bitset_intersection(self.filled_neighbors, self.neighborhood_array[vertex], self.filled_set)
                    bitset_difference(self.unfilled_neighbors, self.neighborhood_array[vertex], self.filled_neighbors)
                    
                    if bitset_len(self.unfilled_neighbors) == 1:
                        self.vertex_to_fill = bitset_next(self.unfilled_neighbors, 0)
                        bitset_add(self.vertices_to_recheck, self.vertex_to_fill)
                        
                        bitset_intersection(self.filled_neighbors_of_vx_to_fill, self.neighborhood_array[self.vertex_to_fill], self.filled_set)
                        bitset_remove(self.filled_neighbors_of_vx_to_fill, vertex)
                        bitset_union(self.vertices_to_recheck, self.vertices_to_recheck, self.filled_neighbors_of_vx_to_fill)
                        
                        bitset_add(self.filled_set, self.vertex_to_fill)
            bitset_copy(self.vertices_to_check, self.vertices_to_recheck)

        self.num_vertices_checked = self.num_vertices_checked + 1            
            
        #return *self.filled_set #TODO: IF EVERYTHING WORKS RETURN POINTER
        return FrozenBitset(bitset_list(self.filled_set), capacity=self.num_vertices)
    

    cdef neighbors_with_edges_add_to_queue(self, FrozenBitset meta_vertex, FastQueueForBFS the_queue, int previous_cost):
        # verify that 'meta_vertex' is actually a subset of the vertices
        # of self.primal_graph, to be interpreted as the filled subset
        #print "neighbors requested for ", list(meta_vertex)

        cdef set set_of_neighbors_with_edges = set()
        cdef int new_vx_to_make_force
        cdef int cost
        cdef int i
        cdef int num_unfilled_neighbors

        bitset_copy(self.meta_vertex, &meta_vertex._bitset[0])
        
        for new_vx_to_make_force in self.vertices_set:
            bitset_copy(self.unfilled_neighbors, self.neighborhood_array[new_vx_to_make_force])
            bitset_difference(self.unfilled_neighbors, self.unfilled_neighbors, self.meta_vertex)
            num_unfilled_neighbors = bitset_len(self.unfilled_neighbors)

            if num_unfilled_neighbors == 0:
                cost = num_unfilled_neighbors
            else:
                cost = num_unfilled_neighbors - 1

            if not bitset_in(self.meta_vertex, new_vx_to_make_force):
                cost += 1

            if cost > 0:
                the_queue.push(  previous_cost + cost,  (meta_vertex, new_vx_to_make_force) )

    
    def get_num_closures_calculated(self):
        return int(self.num_vertices_checked)
    






import itertools
import random
from sage.data_structures.bitset import Bitset, FrozenBitset


cdef class FastQueueForBFS:
    cdef list array_list
    cdef int smallest_nonempty_priority
    cdef int max_possible_priority
    
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
    
    cdef pop(self):
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
    
    cdef tuple pop_and_get_priority(self):
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

    cdef push(self, int priority_for_new_item, tuple new_item):
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

cdef real_dijkstra(ZFSearchMetagraphNewAlg metagraph, start, target):
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
        
        metagraph.neighbors_with_edges_add_to_queue(current, unvisited_queue, current_distance)

#        for neighbor_tuple in metagraph.neighbors_with_edges(current):
#            what_forced = neighbor_tuple[1]
#            cost_of_making_it_force = neighbor_tuple[0]
            
#            new_dist = current_distance + cost_of_making_it_force
            
#            heapq.heappush(unvisited_queue, (new_dist, current, what_forced))
#            unvisited_queue.push( new_dist, (current, what_forced) )

            
    temp = [(target_FrozenBitset, None)]
    shortest_path = shortest(target_FrozenBitset, temp, previous, start_FrozenBitset)

    print "Closures remaining on queue:                ", len(unvisited_queue)
    print "Length of shortest path found in metagraph: ", len(shortest_path)
#    print "Shortest path found: ", shortest_path

    
    return build_zf_set(shortest_path)