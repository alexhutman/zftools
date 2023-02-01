from sage.data_structures.bitset cimport Bitset, FrozenBitset
from sage.data_structures.bitset_base cimport bitset_t

from fastqueue cimport FastQueueForBFS

# Since we relabel the vertices from 0..N, this is fine :)
cdef int SENTINEL = -1

cdef class ZFSearchMetagraph:
    cdef public int num_vertices 
    cdef int num_vertices_checked, vertex_to_fill
    cdef bitset_t *neighborhood_array 
    cdef set vertices_set
    cdef public dict neighbors_dict, closed_neighborhood_list, orig_to_relabeled_verts, relabeled_to_orig_verts
    #for-loop counters
    cdef int i, j, v, w, vertex, new_vx_to_make_force
    # Initialize extend_closure variables
    cdef bitset_t filled_set, vertices_to_check, vertices_to_recheck, filled_neighbors, unfilled_neighbors, filled_neighbors_of_vx_to_fill
    # Initialize calculate_cost variables 
    cdef bitset_t meta_vertex
    cdef int numUnfilledNeighbors, accounter, cost
        
    cdef FrozenBitset extend_closure(self, FrozenBitset, FrozenBitset)
    cdef neighbors_with_edges_add_to_queue(self, FrozenBitset, FastQueueForBFS, int)

    @staticmethod
    cdef list shortest(FrozenBitset, FrozenBitset, list, dict)

    cdef set build_zf_set(self, list)
    cpdef set dijkstra(self, frozenset, frozenset)

    cpdef object to_orig_vertex(self, int)
    cpdef object __to_orig_metavertex_iter(self, object)
    cpdef frozenset to_orig_metavertex(self, object)
    cpdef int to_relabeled_vertex(self, object)
    cpdef object __to_relabeled_metavertex_iter(self, object)
    cpdef frozenset to_relabeled_metavertex(self, object)
