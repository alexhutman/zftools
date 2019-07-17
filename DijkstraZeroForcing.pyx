# cython: profile=False

from sage.graphs.all import Graph
from sage.data_structures.bitset import Bitset, FrozenBitset

include "sage/data_structures/bitset.pxi"
include "cysignals/memory.pxi"

# Define metagraph class in Cython
cdef class OrdinaryZeroForcingMetagraph:
    cdef:
        public int num_vertices 
        public dict closed_neighborhood_list
        bitset_t *neighborhood_array 

        int num_closures_calculated
        
        # When a variable of type bitset_t is initialized, memory is
        # allocated on the heap.  For methods that use working variables
        # of type bitset_t, we don't want this to happen every time the
        # method is called, because that would be very slow.  So we
        # keep these working variables as class attributes and allocate
        # memory for them only when the class is initialized.
        
        # Initialize the working variables of type bitset_t for the
        # method extend_closure()
        bitset_t filled_set
        bitset_t vertices_to_check
        bitset_t vertices_to_recheck
        bitset_t filled_neighbors
        bitset_t unfilled_neighbors
        bitset_t filled_neighbors_of_vx_to_fill
    
        # Initialize the working variables of type bitset_t for the
        # method neighbors_with_edges_add_to_queue()
        bitset_t meta_vertex
    
    
    # The implementation of the metagraph class assumes that the "primal graph"
    # on which it is defined has a vertex set of the form {0,...,n-1}
    def __cinit__(self, graph_for_zero_forcing):
        self.num_vertices = graph_for_zero_forcing.num_verts()

        # Allocate memory for an array to vertex neighborhoods in the form of bitset_t's
        self.neighborhood_array = <bitset_t*> sig_malloc(self.num_vertices*sizeof(bitset_t))
        
        # Initialize and allocate memory for working variables of type bitset_t
        bitset_init(self.filled_set, self.num_vertices)
        bitset_init(self.vertices_to_check, self.num_vertices)
        bitset_init(self.vertices_to_recheck, self.num_vertices)
        bitset_init(self.filled_neighbors, self.num_vertices)
        bitset_init(self.unfilled_neighbors, self.num_vertices)
        bitset_init(self.filled_neighbors_of_vx_to_fill, self.num_vertices)
        bitset_init(self.meta_vertex, self.num_vertices)
    
    def __init__(self, graph_for_zero_forcing):
        self.closed_neighborhood_list = {}
        for i in graph_for_zero_forcing.vertices():
            temp_vertex_neighbors = FrozenBitset(graph_for_zero_forcing.neighbors(i) + [i])
            self.closed_neighborhood_list[i] = temp_vertex_neighbors
            
        # Set up array to vertex neighborhoods in the form of bitset_t's
        for v in range(self.num_vertices):
            bitset_init(self.neighborhood_array[v], self.num_vertices)
            bitset_clear(self.neighborhood_array[v])
            for w in graph_for_zero_forcing.neighbors(v):
                bitset_add(self.neighborhood_array[v], w)   
        
        # The variable below is just used for profiling purposes
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
        cdef int vertex_to_fill
        
        # The following working variables of type bitset_t are implemented as
        # class attributes to avoid allocating memory for them every time
        # this function is called
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
                        vertex_to_fill = bitset_next(self.unfilled_neighbors, 0)
                        bitset_add(self.vertices_to_recheck, vertex_to_fill)
                        
                        bitset_intersection(self.filled_neighbors_of_vx_to_fill, self.neighborhood_array[vertex_to_fill], self.filled_set)
                        bitset_remove(self.filled_neighbors_of_vx_to_fill, vertex)
                        bitset_union(self.vertices_to_recheck, self.vertices_to_recheck, self.filled_neighbors_of_vx_to_fill)
                        
                        bitset_add(self.filled_set, vertex_to_fill)
            bitset_copy(self.vertices_to_check, self.vertices_to_recheck)

        self.num_closures_calculated += 1            
        
        set_to_return = FrozenBitset(capacity=self.num_vertices)
        bitset_copy(&set_to_return._bitset[0], self.filled_set)
        return set_to_return
    

    cdef neighbors_with_edges_add_to_queue(self, FrozenBitset meta_vertex, FastQueueForBFS the_queue, int previous_cost):
        cdef int new_vx_to_make_force
        cdef int cost
        cdef int i
        cdef int num_unfilled_neighbors

        bitset_copy(self.meta_vertex, &meta_vertex._bitset[0])
        
        for new_vx_to_make_force in range(self.num_vertices):
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
    
    def forcing_set_from_metagraph_path(self, metagraph_path):
        zf_set = set()

        for (filled_vertices, forcing_vx) in metagraph_path[:-1]: #Do not need to do the last metavertex (everything is already filled)
            if forcing_vx not in filled_vertices: #If filled, don't need to add it to zf_set since it will already have been gotten for free
                zf_set.add(forcing_vx)
        
            # recover actual (not closed) neighborhood of our vertex to force
            neighbors = self.closed_neighborhood_list[forcing_vx] - FrozenBitset([forcing_vx])
        
            # find unfilled neighbors of forcing vertex
            unfilled_neighbors = neighbors - filled_vertices
    
            unfilled_neighbor_iterator = iter(unfilled_neighbors)
            num_to_fill_to_make_force = len(unfilled_neighbors)-1
            for i in range(num_to_fill_to_make_force):
                zf_set.add( next(unfilled_neighbor_iterator) )
        
        return zf_set
    
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

cdef dijkstra(OrdinaryZeroForcingMetagraph metagraph, start, target):
    cdef:
        dict parent_dict = {}

        int current_distance
        int cost_of_making_it_force
        int what_forced
        int new_dist

        int num_vertices_primal_graph = metagraph.num_vertices
    
    unvisited_queue = FastQueueForBFS(num_vertices_primal_graph)
    
    unvisited_queue.push(0, (start, None))

    done = False
    while not done:
        current_distance, current_metavertex_info = unvisited_queue.pop_and_get_priority()
        
        previous_metavertex, metagraph_edge_data = current_metavertex_info

        if metagraph_edge_data == None:
            current = previous_metavertex
        else:
            current = metagraph.extend_closure(previous_metavertex, metagraph.closed_neighborhood_list[metagraph_edge_data])
        
        if current in parent_dict:
            continue

        parent_dict[current] = (previous_metavertex, metagraph_edge_data)

        if current == target:
            done = True
            break
        
        metagraph.neighbors_with_edges_add_to_queue(current, unvisited_queue,
            current_distance)
            
    term = [(target, None)]
    shortest_path = reconstruct_shortest_metagraph_path(target, term, parent_dict, start)

#    print "Closures remaining on queue:                ", len(unvisited_queue)
#    print "Length of shortest path found in metagraph: ", len(shortest_path)
#    print "Shortest path found: ", shortest_path

    return metagraph.forcing_set_from_metagraph_path(shortest_path)


def zero_forcing_number(the_graph):
    return len(smallest_zero_forcing_set(the_graph))

def smallest_zero_forcing_set(the_graph, print_num_closures_calculated=False):
    num_vertices = the_graph.num_verts()

    # The graph we have been passed may not have its vertex set of the form {0,...,n-1}
    # so make a copy of it and relabel the vertices -- then store a dictionary that maps
    # each original vertex label to the integer that is the new label for that vertex.
    relabeled_graph = the_graph.copy()
    relabeling_map = relabeled_graph.relabel(return_map=True)

    # Now make a dictionary mapping each new integer label back to its vertex label in
    # the original graph
    old_vertex_label_dict = {}
    for vertex in the_graph.vertices():
        old_vertex_label_dict[relabeling_map[vertex]] = vertex

    metagraph = OrdinaryZeroForcingMetagraph(relabeled_graph)

    all_unfilled = FrozenBitset([], capacity=num_vertices)
    all_filled = FrozenBitset(range(num_vertices), capacity=num_vertices)
    output = dijkstra(metagraph, all_unfilled, all_filled)
    
    if print_num_closures_calculated:
        print "Closures calculated:", metagraph.get_num_closures_calculated()
    return {old_vertex_label_dict[j] for j in output}
