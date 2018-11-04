#from sage.all import *
from sage.graphs.all import Graph

include "sage/data_structures/bitset.pxi"

include "cysignals/memory.pxi"

# Define metagraph class in Python
cdef class ZFSearchMetagraphNewAlg:
    cdef int num_vertices, 
    cdef int num_vertices_checked, vertex_to_fill
    cdef bitset_t *neighborhood_array 
    cdef set vertices_set
    cdef public dict neighbors_dict
    
    #for-loop counters
    cdef int i, j, v, vertex, new_vx_to_make_force
    
    
    # Temp variable(s) for __init__ 
    cdef bitset_t temp_vertex_neighbors
    
    # Initialize extend_closure variables
    cdef bitset_t filled_set, vertices_to_check, vertices_to_recheck, filled_neighbors, unfilled_neighbors, filled_neighbors_of_vx_to_fill
    
    def __cinit__(self, graph_for_zero_forcing):
        self.num_vertices = graph_for_zero_forcing.num_verts()
        self.neighborhood_array = <bitset_t*> sig_malloc(self.num_vertices*sizeof(bitset_t)) #ALLOCATE NEIGHBORHOOD_ARRAY
        bitset_init(self.temp_vertex_neighbors, self.num_vertices)
        
        
        # Initialize extend_closure bitsets
        bitset_init(self.filled_set, self.num_vertices)
        bitset_init(self.vertices_to_check, self.num_vertices)
        bitset_init(self.vertices_to_recheck, self.num_vertices)
        bitset_init(self.filled_neighbors, self.num_vertices)
        bitset_init(self.unfilled_neighbors, self.num_vertices)
        bitset_init(self.filled_neighbors_of_vx_to_fill, self.num_vertices)
    
    def __init__(self, graph_for_zero_forcing):
        self.vertices_set = set(graph_for_zero_forcing.vertices())
        self.neighbors_dict = {}
        
        for i in self.vertices_set:
            for j in graph_for_zero_forcing.neighbors(i):
                bitset_add(self.temp_vertex_neighbors, j)
                self.neighbors_dict[i] = frozenset(graph_for_zero_forcing.neighbors(i)) #Convert to bitset

        # create pointer to bitset array with neighborhoods
        bitset_init(self.neighborhood_array[0], self.num_vertices)
        if(bitset_isempty(self.neighborhood_array[0])):
            print("Array successfully created/initialized (only 1st index for now)")
        
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
    
    
    #cpdef *bitset_t extend_closure(self, bitset_t initially_filled_subset, bitset_t vxs_to_add): #IF EVERYTHING WORKS
    #cpdef set extend_closure(self, bitset_t initially_filled_subset, bitset_t vxs_to_add): 
    cpdef set extend_closure(self, set initially_filled_subset2, set vxs_to_add2): 
        
        cdef bitset_t initially_filled_subset
        cdef bitset_t vxs_to_add
        
        bitset_init(initially_filled_subset, self.num_vertices)
        bitset_init(vxs_to_add, self.num_vertices)
        
        for i in initially_filled_subset2:
            bitset_add(initially_filled_subset, i)
        for i in vxs_to_add2:
            bitset_add(vxs_to_add, i)
        
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
                bitset_clear(self.temp_vertex_neighbors)
                for j in self.neighbors_dict[v]:
                    bitset_add(self.temp_vertex_neighbors, j)
                bitset_intersection(self.filled_neighbors, self.temp_vertex_neighbors, self.filled_set)
                bitset_union(self.vertices_to_check, self.vertices_to_check, self.filled_neighbors)
            
        bitset_clear(self.vertices_to_recheck)
        while not bitset_isempty(self.vertices_to_check):
            #print "now will check", vertices_to_check
            bitset_clear(self.vertices_to_recheck)
            for vertex in range(self.num_vertices):
                if bitset_in(self.vertices_to_check, vertex):
                    bitset_clear(self.temp_vertex_neighbors)
                    for j in self.neighbors_dict[vertex]:
                        bitset_add(self.temp_vertex_neighbors, j)
                    bitset_intersection(self.filled_neighbors, self.temp_vertex_neighbors, self.filled_set)
                    bitset_difference(self.unfilled_neighbors, self.temp_vertex_neighbors, self.filled_neighbors)
                    
                    if bitset_len(self.unfilled_neighbors) == 1:
                        self.vertex_to_fill = bitset_next(self.unfilled_neighbors, 0)
                        bitset_add(self.vertices_to_recheck, self.vertex_to_fill)
                        
                        bitset_clear(self.temp_vertex_neighbors)
                        for j in self.neighbors_dict[self.vertex_to_fill]:
                            bitset_add(self.temp_vertex_neighbors, j)
                        bitset_intersection(self.filled_neighbors_of_vx_to_fill, self.temp_vertex_neighbors, self.filled_set)
                        bitset_remove(self.filled_neighbors_of_vx_to_fill, vertex)
                        bitset_union(self.vertices_to_recheck, self.vertices_to_recheck, self.filled_neighbors_of_vx_to_fill)
                        
                        bitset_add(self.filled_set, self.vertex_to_fill)
            bitset_copy(self.vertices_to_check, self.vertices_to_recheck)
            
        #return *self.filled_set #TODO: IF EVERYTHING WORKS RETURN POINTER
        return set(bitset_list(self.filled_set))
    

    cdef calculate_cost(self, frozenset meta_vertex, int vertex_to_calc_cost):
        unfilled_neighbors = set(self.neighbors_dict[vertex_to_calc_cost])
        unfilled_neighbors = unfilled_neighbors - meta_vertex
        numUnfilledNeighbors = len(unfilled_neighbors)
        accounter = None

        if numUnfilledNeighbors == 0:
            accounter = 0
        else:
            accounter = 1

        cost = numUnfilledNeighbors - accounter

        if vertex_to_calc_cost not in meta_vertex:
            cost = cost + 1

        return cost


    cpdef neighbors_with_edges(self, frozenset meta_vertex):
        # verify that 'meta_vertex' is actually a subset of the vertices
        # of self.primal_graph, to be interpreted as the filled subset
        #print "neighbors requested for ", list(meta_vertex)

        cdef set set_of_neighbors_with_edges = set()
        cdef int new_vx_to_make_force

        for new_vx_to_make_force in self.vertices_set:
            cost = self.calculate_cost(meta_vertex, new_vx_to_make_force)
            if cost > 0:
                tuple_of_neighbor_with_edge = (cost, new_vx_to_make_force)
                set_of_neighbors_with_edges.add(tuple_of_neighbor_with_edge)
        return set_of_neighbors_with_edges

