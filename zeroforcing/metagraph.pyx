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
    
    # TODO: Get rid of this crap, only have user call in terms of original vertices
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
        graph_copy = graph_for_zero_forcing.copy(immutable=False)
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
        
        cdef int v, w
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

        self.num_vertices_checked += 1            
        
        set_to_return = FrozenBitset(capacity=self.num_vertices)
        bitset_copy(&set_to_return._bitset[0], self.filled_set)
        return set_to_return
    

    cdef neighbors_with_edges_add_to_queue(self, FrozenBitset meta_vertex, FastQueueForBFS queue, int previous_cost):
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
                queue.push(previous_cost + cost, (meta_vertex, new_vx_to_make_force))

    
    cpdef get_num_closures_calculated(self):
        return int(self.num_vertices_checked)

    @staticmethod
    cdef list shortest(FrozenBitset start, FrozenBitset end, list path_so_far, dict predecessor_list):
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
        cdef set zf_set = set()
        cdef FrozenBitset filled_vertices
        cdef int forcing_vx 

        # For each metavertex
        for filled_vertices, forcing_vx in final_metavx_list[:-1]: #Do not need to do the last metavertex (everything is already filled)
            if forcing_vx not in filled_vertices: #If filled, don't need to add it to zf_set since it will already have been gotten for free
                zf_set.add(forcing_vx)
            unfilled_neighbors = self.neighbors_dict[forcing_vx] - filled_vertices #Find n unfilled neighbors of forcing vertex
        
            if len(unfilled_neighbors) > 1:
                zf_set.update(set(itertools.islice(unfilled_neighbors, len(unfilled_neighbors)-1))) #Pick n-1 of them, the last will be gotten for free
        return zf_set

    cpdef set dijkstra(self, frozenset start, frozenset target):
        cdef int current_distance
        cdef int cost_of_making_it_force
        cdef int what_forced
        cdef int new_dist
        cdef FrozenBitset current

        cdef FrozenBitset parent
        cdef int vx_to_force

        cdef dict previous = {}
        cdef int num_vertices_primal_graph = self.num_vertices
        cdef FrozenBitset empty_FrozenBitset = FrozenBitset()
        cdef FastQueueForBFS unvisited_queue = FastQueueForBFS(num_vertices_primal_graph)
        
        cdef FrozenBitset start_FrozenBitset = FrozenBitset(start, capacity=num_vertices_primal_graph)
        cdef FrozenBitset target_FrozenBitset = FrozenBitset(target, capacity=num_vertices_primal_graph)
        
        unvisited_queue.push(0, (start_FrozenBitset, SENTINEL))
        while True:
            current_distance, unvisited_metavx = unvisited_queue.pop_and_get_priority()
            
            parent = unvisited_metavx[0] # Previous closure
            vx_to_force = unvisited_metavx[1]

            if vx_to_force == SENTINEL:
                current = empty_FrozenBitset
            else:
                current = self.extend_closure(parent, self.closed_neighborhood_list[vx_to_force])
            
            if current in previous:
                continue

            previous[current] = (parent, vx_to_force)
            if current == target_FrozenBitset: # We have found the target vertex, can stop searching now
                break
            self.neighbors_with_edges_add_to_queue(current, unvisited_queue, current_distance)
                
        cdef list cur_path = [(target_FrozenBitset, SENTINEL)]
        cdef list shortest_path = ZFSearchMetagraph.shortest(start_FrozenBitset, target_FrozenBitset, cur_path, previous)
        cdef object zf_set_with_old_labels = map(self.to_orig_vertex, self.build_zf_set(shortest_path))

        return set(zf_set_with_old_labels)
