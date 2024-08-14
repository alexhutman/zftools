import itertools

from sage.data_structures.bitset cimport (
    FrozenBitset
)

from sage.data_structures.bitset_base cimport (
    bitset_add,
    bitset_clear,
    bitset_copy,
    bitset_difference,
    bitset_free,
    bitset_in,
    bitset_init,
    bitset_intersection,
    bitset_isempty,
    bitset_len,
    bitset_next,
    bitset_remove,
    bitset_t,
    bitset_union
)

from sage.graphs.base.c_graph cimport CGraphBackend

from cpython.mem cimport (
    PyMem_Malloc,
    PyMem_Free
)

from zftools.fastqueue cimport FastQueueForBFS


def zero_forcing_set(sage_graph):
    cdef:
        ZFSearchMetagraph metagraph = ZFSearchMetagraph(sage_graph)
        frozenset start = frozenset()
        frozenset end = frozenset(
                metagraph.to_relabeled_metavertex(sage_graph.vertices(sort=False))
                )

    return metagraph.dijkstra(start, end)


def zero_forcing_number(sage_graph):
    return len(zero_forcing_set(sage_graph))


cdef class ExtendClosureBitsets:
    def __cinit__(self, size_t num_vertices):
        # TODO: Figure out how to have less verbosity here?
        bitset_init(self.initially_filled_subset, num_vertices)
        bitset_init(self.vxs_to_add, num_vertices)
        bitset_init(self.filled_set, num_vertices)
        bitset_init(self.vertices_to_check, num_vertices)
        bitset_init(self.vertices_to_recheck, num_vertices)
        bitset_init(self.filled_neighbors, num_vertices)
        bitset_init(self.unfilled_neighbors, num_vertices)
        bitset_init(self.filled_neighbors_of_vx_to_fill, num_vertices)

    def __dealloc__(self):
        bitset_free(self.initially_filled_subset)
        bitset_free(self.vxs_to_add)
        bitset_free(self.filled_set)
        bitset_free(self.vertices_to_check)
        bitset_free(self.vertices_to_recheck)
        bitset_free(self.filled_neighbors)
        bitset_free(self.unfilled_neighbors)
        bitset_free(self.filled_neighbors_of_vx_to_fill)

    cdef void clear_all(self):
        bitset_clear(self.initially_filled_subset)
        bitset_clear(self.vxs_to_add)
        bitset_clear(self.filled_set)
        bitset_clear(self.vertices_to_check)
        bitset_clear(self.vertices_to_recheck)
        bitset_clear(self.filled_neighbors)
        bitset_clear(self.unfilled_neighbors)
        bitset_clear(self.filled_neighbors_of_vx_to_fill)


cdef class ZFSearchMetagraph:
    def __cinit__(self, object graph_for_zero_forcing not None):
        self.num_vertices = (<CGraphBackend>graph_for_zero_forcing._backend) \
                            .cg().num_verts
        self.ec_bitsets = ExtendClosureBitsets(self.num_vertices)
        self.neighborhood_array = <bitset_t*> PyMem_Malloc(self.num_vertices
                                                           *sizeof(bitset_t))
        if not self.neighborhood_array:
            raise MemoryError("Could not allocate neighborhood array")

        bitset_init(self.meta_vertex, self.num_vertices)
        for vertex in range(self.num_vertices):
            bitset_init(self.neighborhood_array[vertex], self.num_vertices)

    def __dealloc__(self):
        bitset_free(self.meta_vertex)

        for vertex in range(self.num_vertices):
            bitset_free(self.neighborhood_array[vertex])
        PyMem_Free(self.neighborhood_array)

    def __init__(self, graph_for_zero_forcing not None):
        graph_copy = graph_for_zero_forcing.copy(immutable=False)
        self.orig_to_relabeled_verts = graph_copy.relabel(inplace=True, return_map=True)
        self.relabeled_to_orig_verts = {
                v: k for k, v in self.orig_to_relabeled_verts.items()
                }

        self.closed_neighborhood_list = {}
        self.neighbors_dict = {}
        self.vertices_set = set(graph_copy.vertices(sort=False))

        self.initialize_neighbors(graph_copy)
        self.initialize_neighborhood_array(graph_copy)

    cdef void initialize_neighbors(self, graph_copy):
        cdef size_t i
        for i in self.vertices_set:
            # TODO: Only so Dijkstra code doesn't break.
            # Ideally want to remove this somehow
            neighbors = graph_copy.neighbors(i)
            self.neighbors_dict[i] = FrozenBitset(
                    neighbors,
                    capacity=self.num_vertices)
            self.closed_neighborhood_list[i] = FrozenBitset(
                    neighbors + [i],
                    capacity=self.num_vertices)

    cdef void initialize_neighborhood_array(self, graph_copy):
        cdef size_t vertex, neighbor
        for vertex in range(self.num_vertices):
            for neighbor in graph_copy.neighbor_iterator(vertex):
                bitset_add(self.neighborhood_array[vertex], neighbor)

    cdef FrozenBitset extend_closure(self,
                                     FrozenBitset initially_filled_subset,
                                     FrozenBitset vxs_to_add):
        self.ec_bitsets.clear_all()

        bitset_copy(
                self.ec_bitsets.initially_filled_subset,
                initially_filled_subset._bitset)
        bitset_copy(self.ec_bitsets.vxs_to_add, vxs_to_add._bitset)

        bitset_copy(
                self.ec_bitsets.vertices_to_check,
                self.ec_bitsets.vxs_to_add)

        bitset_union(
                self.ec_bitsets.filled_set,
                self.ec_bitsets.initially_filled_subset,
                self.ec_bitsets.vxs_to_add)
        for v in range(self.num_vertices):
            if bitset_in(self.ec_bitsets.vxs_to_add, v):
                bitset_intersection(
                        self.ec_bitsets.filled_neighbors,
                        self.neighborhood_array[v],
                        self.ec_bitsets.filled_set)
                bitset_union(self.ec_bitsets.vertices_to_check,
                             self.ec_bitsets.vertices_to_check,
                             self.ec_bitsets.filled_neighbors)

        bitset_clear(self.ec_bitsets.vertices_to_recheck)
        while not bitset_isempty(self.ec_bitsets.vertices_to_check):
            bitset_clear(self.ec_bitsets.vertices_to_recheck)
            for vertex in range(self.num_vertices):
                if bitset_in(self.ec_bitsets.vertices_to_check, vertex):
                    bitset_intersection(
                            self.ec_bitsets.filled_neighbors,
                            self.neighborhood_array[vertex],
                            self.ec_bitsets.filled_set)
                    bitset_difference(
                            self.ec_bitsets.unfilled_neighbors,
                            self.neighborhood_array[vertex],
                            self.ec_bitsets.filled_neighbors)

                    if bitset_len(self.ec_bitsets.unfilled_neighbors) == 1:
                        self.vertex_to_fill = bitset_next(
                                self.ec_bitsets.unfilled_neighbors,
                                0)
                        bitset_add(
                                self.ec_bitsets.vertices_to_recheck,
                                self.vertex_to_fill)

                        bitset_intersection(
                                self.ec_bitsets.filled_neighbors_of_vx_to_fill,
                                self.neighborhood_array[self.vertex_to_fill],
                                self.ec_bitsets.filled_set)
                        bitset_remove(
                                self.ec_bitsets.filled_neighbors_of_vx_to_fill,
                                vertex)
                        bitset_union(
                                self.ec_bitsets.vertices_to_recheck,
                                self.ec_bitsets.vertices_to_recheck,
                                self.ec_bitsets.filled_neighbors_of_vx_to_fill)

                        bitset_add(self.ec_bitsets.filled_set, self.vertex_to_fill)
            bitset_copy(
                    self.ec_bitsets.vertices_to_check,
                    self.ec_bitsets.vertices_to_recheck)

        set_to_return = FrozenBitset(capacity=self.num_vertices)
        bitset_copy(set_to_return._bitset, self.ec_bitsets.filled_set)
        return set_to_return

    cdef void neighbors_with_edges_add_to_queue(self,
                                                FastQueueForBFS queue,
                                                FrozenBitset meta_vertex,
                                                size_t previous_cost):
        # verify that 'meta_vertex' is actually a subset of the vertices
        # of self.primal_graph, to be interpreted as the filled subset
        cdef size_t new_vx_to_make_force, cost, _, num_unfilled_neighbors

        bitset_copy(self.meta_vertex, meta_vertex._bitset)
        for new_vx_to_make_force in self.vertices_set:
            bitset_copy(
                    self.ec_bitsets.unfilled_neighbors,
                    self.neighborhood_array[new_vx_to_make_force])
            bitset_difference(
                    self.ec_bitsets.unfilled_neighbors,
                    self.ec_bitsets.unfilled_neighbors,
                    self.meta_vertex)
            num_unfilled_neighbors = bitset_len(self.ec_bitsets.unfilled_neighbors)

            cost = num_unfilled_neighbors
            if num_unfilled_neighbors > 0:
                cost -= 1

            if not bitset_in(self.meta_vertex, new_vx_to_make_force):
                cost += 1

            if cost > 0:
                queue.push(
                        previous_cost + cost,
                        (meta_vertex, new_vx_to_make_force))

    @staticmethod
    cdef list shortest(
            FrozenBitset start,
            FrozenBitset end,
            list path_so_far,
            dict predecessor_list):
        cdef list path_so_far_copy = path_so_far.copy()
        predecessor = predecessor_list[end]
        path_so_far_copy.append(predecessor)

        cdef FrozenBitset cur_metavx = predecessor[0]
        while cur_metavx != start:
            predecessor = predecessor_list[cur_metavx]
            path_so_far_copy.append(predecessor)
            cur_metavx = predecessor[0]
        path_so_far_copy.reverse()
        return path_so_far_copy

    cdef set build_zf_set(self, list final_metavx_list):
        cdef:
            set zf_set = set()
            FrozenBitset filled_vertices
            size_t forcing_vx

        # For each metavertex
        for filled_vertices, forcing_vx in final_metavx_list[:-1]:
            # Do not need to do the last metavertex (everything is already filled)
            if forcing_vx not in filled_vertices:
                # If filled, don't need to add it to zf_set since it will already
                # have been gotten for free
                zf_set.add(forcing_vx)
            unfilled_neighbors = self.neighbors_dict[forcing_vx] - filled_vertices
            # Find n unfilled neighbors of forcing vertex

            if len(unfilled_neighbors) > 1:
                zf_set.update(
                        set(itertools.islice(
                            unfilled_neighbors,
                            len(unfilled_neighbors)-1
                            ))
                        )
                # Pick n-1 of them, the last will be gotten for free
        return zf_set

    cpdef set dijkstra(self, frozenset start, frozenset target):
        cdef:
            size_t current_distance
            tuple unvisited_metavx

            FrozenBitset parent
            size_t vx_to_force

        cdef:
            FastQueueForBFS unvisited_queue = FastQueueForBFS(self.num_vertices)
            FrozenBitset start_metavertex = FrozenBitset(
                    start,
                    capacity=self.num_vertices)
            FrozenBitset target_metavertex = FrozenBitset(
                    target,
                    capacity=self.num_vertices)
            # Start us off
            FrozenBitset current = start_metavertex
            dict previous = {
                    current: (start_metavertex, None)
                    }

        self.neighbors_with_edges_add_to_queue(unvisited_queue, current, 0)
        while current != target_metavertex:
            current_distance, unvisited_metavx = unvisited_queue.pop_and_get_priority()
            # Previous closure, added vertex
            parent, vx_to_force = unvisited_metavx

            current = self.extend_closure(
                    parent,
                    self.closed_neighborhood_list[vx_to_force])
            if current in previous:
                continue

            previous[current] = (parent, vx_to_force)
            self.neighbors_with_edges_add_to_queue(
                    unvisited_queue,
                    current,
                    current_distance)

        # Can this be simpler by making this a linked list instead?
        # It would be more like a graph imo
        cdef:
            list cur_path = [(target_metavertex, None)]
            list shortest_path = ZFSearchMetagraph.shortest(
                    start_metavertex,
                    target_metavertex,
                    cur_path,
                    previous)
            object zf_set_with_old_labels = map(
                    self.to_orig_vertex,
                    self.build_zf_set(shortest_path))

        return set(zf_set_with_old_labels)

    # TODO: Get rid of this crap, only have user call in terms of original vertices
    cpdef frozenset to_orig_metavertex(self, object relabeled_metavertex_iter):
        return frozenset(self.__to_orig_metavertex_iter(relabeled_metavertex_iter))

    cpdef frozenset to_relabeled_metavertex(self, object orig_vertex_iter):
        return frozenset(self.__to_relabeled_metavertex_iter(orig_vertex_iter))

    cpdef object to_orig_vertex(self, size_t relabeled_vertex):
        return self.relabeled_to_orig_verts[relabeled_vertex]

    cpdef size_t to_relabeled_vertex(self, object orig_vertex):
        return self.orig_to_relabeled_verts[orig_vertex]

    cdef object __to_orig_metavertex_iter(self, object relabeled_metavertex_iter):
        return map(self.to_orig_vertex, relabeled_metavertex_iter)

    cdef object __to_relabeled_metavertex_iter(self, object orig_vertex_iter):
        return map(self.to_relabeled_vertex, orig_vertex_iter)
