import itertools

from sage.data_structures.bitset cimport (
    Bitset,
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

from cysignals.memory cimport (
    sig_free,
    sig_malloc
)

from fastqueue cimport FastQueueForBFS


cdef class ZFSearchMetagraph:
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
    
    cpdef object to_orig_vertex(self, int relabeled_vertex):
        return self.relabeled_to_orig_verts[relabeled_vertex]

    cpdef object __to_orig_metavertex_iter(self, object relabeled_metavertex_iter):
        return map(self.to_orig_vertex, relabeled_metavertex_iter)

    cpdef frozenset to_orig_metavertex(self, object relabeled_metavertex_iter):
        return frozenset(self.__to_orig_metavertex_iter(relabeled_metavertex_iter))

    cpdef int to_relabeled_vertex(self, object orig_vertex):
        return self.orig_to_relabeled_verts[orig_vertex]

    cpdef object __to_relabeled_metavertex_iter(self, object orig_vertex_iter):
        return map(self.to_relabeled_vertex, orig_vertex_iter)

    cpdef frozenset to_relabeled_metavertex(self, object orig_vertex_iter):
        return frozenset(self.__to_relabeled_metavertex_iter(orig_vertex_iter))

    def __init__(self, graph_for_zero_forcing):
        graph_copy = graph_for_zero_forcing.copy()
        self.orig_to_relabeled_verts = graph_copy.relabel(inplace=True, return_map=True)
        self.relabeled_to_orig_verts = {v: k for k,v in self.orig_to_relabeled_verts.items()}
        
        self.vertices_set = set(graph_copy.vertices(sort=False))
        
        self.neighbors_dict = {}
        self.closed_neighborhood_list = {}

        for i in self.vertices_set:
            #TODO: Only so Dijkstra code doesn't break. Ideally want to remove this somehow
            neighbors = graph_copy.neighbors(i)
            self.neighbors_dict[i] = FrozenBitset(neighbors)
            self.closed_neighborhood_list[i] = FrozenBitset(neighbors + [i])
        
        cdef int w
        # create pointer to bitset array with neighborhoods
        for v in range(self.num_vertices):
            bitset_init(self.neighborhood_array[v], self.num_vertices)
            bitset_clear(self.neighborhood_array[v])
            for w in graph_copy.neighbor_iterator(v):
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
        
        bitset_clear(self.filled_set)
        bitset_clear(self.vertices_to_check)
        bitset_clear(self.vertices_to_recheck)
        bitset_clear(self.filled_neighbors)
        bitset_clear(self.unfilled_neighbors)
        bitset_clear(self.filled_neighbors_of_vx_to_fill)
        
        bitset_union(self.filled_set, &initially_filled_subset2._bitset[0], &vxs_to_add2._bitset[0])

        bitset_copy(self.vertices_to_check, &vxs_to_add2._bitset[0])

        for v in range(self.num_vertices):
            if bitset_in(&vxs_to_add2._bitset[0], v):
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

        self.num_vertices_checked = self.num_vertices_checked + 1            
        
        set_to_return = FrozenBitset(capacity=self.num_vertices)
        bitset_copy(&set_to_return._bitset[0], self.filled_set)
        return set_to_return
    

    cdef neighbors_with_edges_add_to_queue(self, FrozenBitset meta_vertex, FastQueueForBFS the_queue, int previous_cost):
        # verify that 'meta_vertex' is actually a subset of the vertices
        # of self.primal_graph, to be interpreted as the filled subset

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

    
    cpdef get_num_closures_calculated(self):
        return int(self.num_vertices_checked)

    @staticmethod
    cdef list shortest(FrozenBitset v, list path_so_far, dict predecessor_list, FrozenBitset start_frozenbitset):
        predecessor_of_v = predecessor_list[v]
        path_so_far.insert(0,predecessor_of_v)
        
        if predecessor_of_v[0] != start_frozenbitset:
            ZFSearchMetagraph.shortest(predecessor_of_v[0], path_so_far, predecessor_list, start_frozenbitset)
        return path_so_far

    cdef set build_zf_set(self, list final_metavx_list):
        zf_set = set()

        for (filled_vertices, forcing_vx) in final_metavx_list[:-1]: #Do not need to do the last metavertex (everything is already filled)
            if forcing_vx not in filled_vertices: #If filled, don't need to add it to zf_set since it will already have been gotten for free
                zf_set.add(forcing_vx)
            unfilled_neighbors = self.neighbors_dict[forcing_vx] - filled_vertices #Find n unfilled neighbors of forcing vertex
        
            if len(unfilled_neighbors)-1 > 0:
                zf_set.update(set(itertools.islice(unfilled_neighbors, len(unfilled_neighbors)-1))) #Pick n-1 of them, the last will be gotten for free
        return zf_set

    cpdef set dijkstra(self, frozenset start, frozenset target):
        cdef dict previous
        cdef int current_distance
        cdef int cost_of_making_it_force
        cdef int what_forced
        cdef int new_dist
        cdef int num_vertices_primal_graph

        num_vertices_primal_graph = self.num_vertices
        empty_FrozenBitset = FrozenBitset()
        previous = {}
        unvisited_queue = FastQueueForBFS(num_vertices_primal_graph)
        
        start_FrozenBitset = FrozenBitset(start, capacity=num_vertices_primal_graph)
        target_FrozenBitset = FrozenBitset(target, capacity=num_vertices_primal_graph)
        
        unvisited_queue.push(0, (start_FrozenBitset, None))

        while True:
            current_distance, uv = unvisited_queue.pop_and_get_priority()
            
            parent = uv[0]
            vx_that_is_to_force = uv[1]
            previous_closure = parent

            if vx_that_is_to_force != None:
                current = self.extend_closure(previous_closure, self.closed_neighborhood_list[vx_that_is_to_force])
            else:
                current = empty_FrozenBitset
            
            if current in previous:
                continue

            previous[current] = (parent, vx_that_is_to_force)
            if current == target_FrozenBitset: # We have found the target vertex, can stop searching now
                break
            self.neighbors_with_edges_add_to_queue(current, unvisited_queue, current_distance)
                
        temp = [(target_FrozenBitset, None)]
        shortest_path = ZFSearchMetagraph.shortest(target_FrozenBitset, temp, previous, start_FrozenBitset)
        zf_set_with_old_labels = set(map(self.to_orig_vertex, self.build_zf_set(shortest_path)))

        return zf_set_with_old_labels
