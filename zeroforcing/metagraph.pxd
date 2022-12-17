from sage.data_structures.bitset cimport Bitset, FrozenBitset
from sage.data_structures.bitset_base cimport bitset_t
from sage.graphs.all import Graph

from zeroforcing.fastqueue cimport FastQueueForBFS

cdef class ZFSearchMetagraph:
    cdef public int num_vertices 
    cdef int num_vertices_checked, vertex_to_fill
    cdef bitset_t *neighborhood_array 
    cdef set vertices_set
    cdef public dict neighbors_dict, closed_neighborhood_list
    #for-loop counters
    cdef int i, j, v, w, vertex, new_vx_to_make_force
    # Initialize extend_closure variables
    cdef bitset_t filled_set, vertices_to_check, vertices_to_recheck, filled_neighbors, unfilled_neighbors, filled_neighbors_of_vx_to_fill
    # Initialize calculate_cost variables 
    cdef bitset_t meta_vertex
    cdef int numUnfilledNeighbors, accounter, cost
        
    cdef FrozenBitset extend_closure(self, FrozenBitset, FrozenBitset)
    cdef neighbors_with_edges_add_to_queue(self, FrozenBitset, FastQueueForBFS, int)
    cpdef get_num_closures_calculated(self)

    @staticmethod
    cdef list shortest(FrozenBitset, list, dict, FrozenBitset)

    cdef set build_zf_set(self, list)
    cpdef set dijkstra(self, frozenset, frozenset)

#cdef class PathNode:
    #cdef public FrozenBitset current_metavertex
    #cdef public FrozenBitset parent
