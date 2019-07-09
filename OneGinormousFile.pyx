# cython: profile=False

from sage.graphs.all import Graph
from sage.data_structures.bitset import Bitset, FrozenBitset

include "sage/data_structures/bitset.pxi"
include "cysignals/memory.pxi"

# Define metagraph class in Python
cdef class OrdinaryZeroForcingMetagraph:
    cdef:
        public int num_vertices 
        int num_closures_calculated, vertex_to_fill
        bitset_t *neighborhood_array 
        set vertices_set
        public dict neighbors_dict, closed_neighborhood_list
    
        #for-loop counters
        int i, j, v, w, vertex, new_vx_to_make_force
    
        # Initialize extend_closure variables
        bitset_t filled_set, vertices_to_check, vertices_to_recheck, filled_neighbors, unfilled_neighbors, filled_neighbors_of_vx_to_fill
    
        # Initialize calculate_cost variables 
        bitset_t meta_vertex
        int numUnfilledNeighbors, accounter, cost
    
    
    def __cinit__(self, graph_for_zero_forcing):
        self.num_vertices = graph_for_zero_forcing.num_verts()
        self.neighborhood_array = <bitset_t*> sig_malloc(self.num_vertices*sizeof(bitset_t))
        
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
        
        self.closed_neighborhood_list = {}
        for i in graph_for_zero_forcing.vertices():
            temp_vertex_neighbors = FrozenBitset(graph_for_zero_forcing.neighbors(i) + [i])
            self.closed_neighborhood_list[i] = temp_vertex_neighbors
            
        # create pointer to bitset array with neighborhoods
        for v in range(self.num_vertices):
            bitset_init(self.neighborhood_array[v], self.num_vertices)
            bitset_clear(self.neighborhood_array[v])
            for w in graph_for_zero_forcing.neighbors(v):
                bitset_add(self.neighborhood_array[v], w)   
        
        #The variable below is just for profiling purposes!
        self.num_closures_calculated = 0
        
    def __dealloc__(self):
        sig_free(self.neighborhood_array)
        
        bitset_free(self.filled_set)
        bitset_free(self.vertices_to_check)
        bitset_free(self.vertices_to_recheck)
        bitset_free(self.filled_neighbors)
        bitset_free(self.unfilled_neighbors)
        bitset_free(self.filled_neighbors_of_vx_to_fill)
        bitset_free(self.meta_vertex)
    
    
    cdef FrozenBitset extend_closure(self, FrozenBitset initially_filled_subset, FrozenBitset vxs_to_add):
        
        # we used member variables so that we didn't have to keep allocating
        # these stupid bitset_s on every call to extend_closure
        bitset_clear(self.filled_set)
        bitset_clear(self.vertices_to_check)
        bitset_clear(self.vertices_to_recheck)
        bitset_clear(self.filled_neighbors)
        bitset_clear(self.unfilled_neighbors)
        bitset_clear(self.filled_neighbors_of_vx_to_fill)
        
        # Rather than copy the contents of the FrozenBitset initially_filled_subset
        # into a bitset_t, we use a "hack" to access the internal data of the FrozenBitset
        # which is itself stored as a bitset_t (since FrozenBitset is a wrapper for one of those)
        bitset_union(self.filled_set, &initially_filled_subset._bitset[0], &vxs_to_add._bitset[0])

        bitset_copy(self.vertices_to_check, &vxs_to_add._bitset[0])

        for v in range(self.num_vertices):
            if bitset_in(&vxs_to_add._bitset[0], v):
                bitset_intersection(self.filled_neighbors, self.neighborhood_array[v], self.filled_set)
                bitset_union(self.vertices_to_check, self.vertices_to_check, self.filled_neighbors)
            
        bitset_clear(self.vertices_to_recheck)
        while not bitset_isempty(self.vertices_to_check):
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

        self.num_closures_calculated = self.num_closures_calculated + 1            
        
        set_to_return = FrozenBitset(capacity=self.num_vertices)
        bitset_copy(&set_to_return._bitset[0], self.filled_set)
        return set_to_return
    

    cdef neighbors_with_edges_add_to_queue(self, FrozenBitset meta_vertex, FastQueueForBFS the_queue, int previous_cost):
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
                the_queue.push( previous_cost + cost,  (meta_vertex, new_vx_to_make_force) )

    
    def get_num_closures_calculated(self):
        return int(self.num_closures_calculated)
    








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






def reconstruct_shortest_metagraph_path(v, path_so_far, predecessor_list, start):
    predecessor_of_v = predecessor_list[v]
    path_so_far.insert(0,predecessor_of_v)
    
    if predecessor_of_v[0] != start:
        reconstruct_shortest_metagraph_path(predecessor_of_v[0], path_so_far, predecessor_list, start)
    return path_so_far

def build_zf_set(DijkstraMG, final_metavx_list):
    zf_set = set()

    for (filled_vertices, forcing_vx) in final_metavx_list[:-1]: #Do not need to do the last metavertex (everything is already filled)
        if forcing_vx not in filled_vertices: #If filled, don't need to add it to zf_set since it will already have been gotten for free
            zf_set.add(forcing_vx)
        
        # recover actual (not closed) neighborhood of our vertex to force
        neighbors = DijkstraMG.closed_neighborhood_list[forcing_vx] - FrozenBitset([forcing_vx])
        
        # find unfilled neighbors of forcing vertex
        unfilled_neighbors = neighbors - filled_vertices
    
        unfilled_neighbor_iterator = iter(unfilled_neighbors)
        num_to_fill_to_make_force = len(unfilled_neighbors)-1
        for i in range(num_to_fill_to_make_force):
            zf_set.add( next(unfilled_neighbor_iterator) )
        
    return zf_set

cdef dijkstra(OrdinaryZeroForcingMetagraph metagraph, start, target):
    cdef dict previous = {}
    
    cdef int current_distance
    cdef int cost_of_making_it_force
    cdef int what_forced
    cdef int new_dist
    
    cdef int num_vertices_primal_graph

    num_vertices_primal_graph = metagraph.num_vertices
    
    empty_FrozenBitset = FrozenBitset()
    
    unvisited_queue = FastQueueForBFS(num_vertices_primal_graph)
    
    unvisited_queue.push( 0, (start, None) )

    done = False
    while not done:
        current_distance, uv = unvisited_queue.pop_and_get_priority()
        
        parent = uv[0]
        vx_that_is_to_force = uv[1]

        previous_closure = parent

        if vx_that_is_to_force != None:
            current = metagraph.extend_closure(previous_closure, metagraph.closed_neighborhood_list[vx_that_is_to_force])
        else:
            current = empty_FrozenBitset
        
        if current in previous:
            continue

        previous[current] = (parent, vx_that_is_to_force)

        if current == target:
            done = True
            break
        
        metagraph.neighbors_with_edges_add_to_queue(current, unvisited_queue, current_distance)

            
    term = [(target, None)]
    shortest_path = reconstruct_shortest_metagraph_path(target, term, previous, start)

#    print "Closures remaining on queue:                ", len(unvisited_queue)
#    print "Length of shortest path found in metagraph: ", len(shortest_path)
#    print "Shortest path found: ", shortest_path

    return build_zf_set(metagraph, shortest_path)


def zero_forcing_number(the_graph):
    return len(smallest_zero_forcing_set(the_graph))

def smallest_zero_forcing_set(the_graph, print_closures=False):
    n = the_graph.num_verts()
    temp = the_graph.copy()
    orig_vertices = temp.relabel(return_map=True)
    new_vertices = {}
    for vertex in orig_vertices:
        new_vertices[orig_vertices[vertex]] = vertex

    metaGraph = OrdinaryZeroForcingMetagraph(temp)

    all_unfilled = FrozenBitset([], capacity=n)
    all_filled = FrozenBitset(range(n), capacity=n)

    output = dijkstra(metaGraph, all_unfilled, all_filled)
    if print_closures:
        print "Closures calculated:", metaGraph.get_num_closures_calculated()
    return {new_vertices[j] for j in output}
