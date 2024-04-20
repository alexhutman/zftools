from sage.data_structures.bitset cimport Bitset, FrozenBitset
from sage.data_structures.bitset_base cimport bitset_t

from zeroforcing.fastqueue cimport FastQueueForBFS

cdef class ZFSearchMetagraph:
    cdef size_t num_vertices, vertex_to_fill
    cdef dict neighbors_dict, closed_neighborhood_list, orig_to_relabeled_verts, relabeled_to_orig_verts
    cdef set vertices_set
    cdef bitset_t meta_vertex
    cdef bitset_t *neighborhood_array
    cdef bitset_t filled_set, vertices_to_check, vertices_to_recheck, filled_neighbors, unfilled_neighbors, filled_neighbors_of_vx_to_fill # extend_closure bitsets

    cdef void initialize_neighbors(self, object)
    cdef FrozenBitset extend_closure(self, FrozenBitset, FrozenBitset)
    cdef void neighbors_with_edges_add_to_queue(self, FrozenBitset, FastQueueForBFS, size_t)

    @staticmethod
    cdef list shortest(FrozenBitset, FrozenBitset, list, dict)

    cdef set build_zf_set(self, list)
    cpdef set dijkstra(self, frozenset, frozenset)

    cpdef object to_orig_vertex(self, size_t)
    cpdef object __to_orig_metavertex_iter(self, object)
    cpdef frozenset to_orig_metavertex(self, object)
    cpdef size_t to_relabeled_vertex(self, object)
    cpdef object __to_relabeled_metavertex_iter(self, object)
    cpdef frozenset to_relabeled_metavertex(self, object)
