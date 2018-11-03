#from sage.all import *
from sage.graphs.all import Graph

include "sage/data_structures/bitset.pxi"

include "cysignals/memory.pxi"

# Define metagraph class in Python
cdef class ZFSearchMetagraphNewAlg:
    cdef set vertices_set
    cdef public dict neighbors_dict
    cdef int num_vertices
    cdef int num_vertices_checked
    cdef bitset_t *neighborhood_array
    
    def __cinit__(self, graph_for_zero_forcing):
        self.num_vertices = graph_for_zero_forcing.num_verts()
        self.neighborhood_array = <bitset_t*> sig_malloc(self.num_vertices*sizeof(bitset_t))
    
    def __init__(self, graph_for_zero_forcing):
        self.vertices_set = set(graph_for_zero_forcing.vertices())
        self.neighbors_dict = {}
        
        for i in self.vertices_set:
            self.neighbors_dict[i] = frozenset(graph_for_zero_forcing.neighbors(i))

        # create pointer to bitset array with neighborhoods
        bitset_init(self.neighborhood_array[0], self.num_vertices)
        if(bitset_isempty(self.neighborhood_array[0])):
            print("Array successfully created/initialized (only 1st index for now)")
            
        # member below is just for profiling purposes!
        self.num_vertices_checked = 0
    
    cpdef extend_closure(self, set initially_filled_subset, set vxs_to_add):
        cdef list all_vertices
        cdef set filled_set, vertices_to_check, vertices_to_recheck
        
        all_vertices = list(self.vertices_set)
        filled_set = set(initially_filled_subset.union(vxs_to_add))

        vertices_to_check = set(vxs_to_add)

        for v in vxs_to_add:
            vertices_to_check.update(self.neighbors_dict[v].intersection(filled_set))
            
        vertices_to_recheck = set()
        while vertices_to_check:
            #print "now will check", vertices_to_check
            vertices_to_recheck.clear()
            for vertex in vertices_to_check:
                self.num_vertices_checked += 1

                filled_neighbors = self.neighbors_dict[vertex].intersection(filled_set)
                unfilled_neighbors = self.neighbors_dict[vertex] - filled_neighbors
                if len(unfilled_neighbors) == 1:
                    vertex_to_fill = next(iter(unfilled_neighbors))
                    vertices_to_recheck.add(vertex_to_fill)
                    vertices_to_recheck.update((self.neighbors_dict[vertex_to_fill].intersection(filled_set)) - frozenset([vertex]))
                    filled_set.add(vertex_to_fill)
            vertices_to_check = set.copy(vertices_to_recheck)
        return filled_set
    

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

