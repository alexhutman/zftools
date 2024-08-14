from sage.data_structures.bitset cimport Bitset, FrozenBitset
from sage.data_structures.bitset_base cimport bitset_t

from zftools.fastqueue cimport FastQueueForBFS


cdef class ExtendClosureBitsets:
    cdef:
        bitset_t initially_filled_subset
        bitset_t vxs_to_add
        bitset_t filled_set
        bitset_t vertices_to_check
        bitset_t vertices_to_recheck
        bitset_t filled_neighbors
        bitset_t unfilled_neighbors
        bitset_t filled_neighbors_of_vx_to_fill

        void clear_all(self)

cdef class ZFSearchMetagraph:
    @staticmethod
    cdef list shortest(FrozenBitset, FrozenBitset, list, dict)

    cdef:
        size_t num_vertices, vertex_to_fill
        dict neighbors_dict, closed_neighborhood_list, \
            orig_to_relabeled_verts, relabeled_to_orig_verts
        set vertices_set
        bitset_t meta_vertex
        bitset_t *neighborhood_array
        ExtendClosureBitsets ec_bitsets

        void initialize_neighbors(self, object)
        void initialize_neighborhood_array(self, object)
        FrozenBitset extend_closure(self, FrozenBitset, FrozenBitset)
        void neighbors_with_edges_add_to_queue(self,
                                               FastQueueForBFS,
                                               FrozenBitset,
                                               size_t)
        set build_zf_set(self, list)

        object __to_orig_metavertex_iter(self, object)
        object __to_relabeled_metavertex_iter(self, object)

    cpdef set dijkstra(self, frozenset, frozenset)

    cpdef frozenset to_orig_metavertex(self, object)
    cpdef frozenset to_relabeled_metavertex(self, object)
    cpdef object to_orig_vertex(self, size_t)
    cpdef size_t to_relabeled_vertex(self, object)
