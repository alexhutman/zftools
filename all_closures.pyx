from sage.graphs.all import Graph
from sage.combinat.all import Subsets

include "sage/data_structures/bitset.pxi"

include "cysignals/memory.pxi"

def calculate_all_closures(ourGraph):
    
    print "vertices :", ourGraph.vertices()
    
    num_vertices = ourGraph.num_verts()
    
    # create pointer to bitset array with neighborhoods
    cdef bitset_t *neighborhood_array = <bitset_t*> sig_malloc(num_vertices*sizeof(bitset_t))


    
    for v in range(num_vertices):
        bitset_init(neighborhood_array[v], num_vertices)
        bitset_clear(neighborhood_array[v])
        for w in ourGraph.neighbors(v):
            bitset_add(neighborhood_array[v], w)    

            
            
    neighbors_dict = {}
    for i in ourGraph.vertices():
        neighbors_dict[i] = frozenset(ourGraph.neighbors(i)) 
    
    cdef bitset_t current_set
    bitset_init(current_set,num_vertices)
    
    cdef bitset_t empty_set
    bitset_init(empty_set,num_vertices)
    bitset_clear(empty_set)
            
    for S in Subsets(ourGraph.vertices()):
        bitset_clear(current_set)
        for i in S:
            bitset_add(current_set, i)
        extend_closure(num_vertices, neighborhood_array, empty_set, current_set)

        
cdef int extend_closure(int num_verts, bitset_t* neighbors_array, bitset_t initially_filled_subset, bitset_t vxs_to_add):
    cdef bitset_t filled_set
    cdef bitset_t vertices_to_check
    cdef bitset_t filled_neighbors
    cdef bitset_t unfilled_neighbors
    cdef bitset_t vertices_to_recheck
    cdef bitset_t filled_neighbors_of_vx_to_fill
    
    # initialize suckers above
    bitset_init(filled_set, num_verts)
    bitset_init(vertices_to_check, num_verts)
    bitset_init(filled_neighbors, num_verts)
    bitset_init(unfilled_neighbors, num_verts)
    bitset_init(vertices_to_recheck, num_verts)
    bitset_init(filled_neighbors_of_vx_to_fill, num_verts)    
 
    bitset_union(filled_set, initially_filled_subset, vxs_to_add)
#    filled_set = initially_filled_subset.union(vxs_to_add)

    bitset_copy(vertices_to_check, vxs_to_add)
#    vertices_to_check = set(vxs_to_add)

    for v in range(num_verts):
        if bitset_in(vxs_to_add, v):
            bitset_intersection(filled_neighbors, neighbors_array[v], filled_set)
            bitset_union(vertices_to_check, vertices_to_check, filled_neighbors)
#        vertices_to_check.update(neighbors_dict[v].intersection(filled_set))

#        return graph.close_subset_under_forcing(filled_set)

    bitset_clear(vertices_to_recheck)
    while not bitset_isempty(vertices_to_check):
        #print "now will check", vertices_to_check
        #print bitset_string(vertices_to_check)
        bitset_clear(vertices_to_recheck)
        for vertex in range(num_verts):
            if bitset_in(vertices_to_check, vertex):
                #graph.num_vertices_checked += 1

                bitset_intersection(filled_neighbors, neighbors_array[vertex], filled_set)
    #            filled_neighbors = neighbors_dict[vertex].intersection(filled_set)

                bitset_difference(unfilled_neighbors, neighbors_array[vertex], filled_neighbors)
    #            unfilled_neighbors = neighbors_dict[vertex] - filled_neighbors
                if bitset_len(unfilled_neighbors) == 1:
                    vertex_to_fill = bitset_next(unfilled_neighbors, 0)
                    bitset_add(vertices_to_recheck, vertex_to_fill)
                    #print vertex, "forces", vertex_to_fill
                    #print filled_set, "filled set"
                    #print vertices_to_check, "vertices to czech"
                    #print vertices_to_recheck, "vertices to reczech"

                    bitset_intersection(filled_neighbors_of_vx_to_fill, neighbors_array[vertex_to_fill], filled_set)
                    bitset_remove(filled_neighbors_of_vx_to_fill, vertex)
                    bitset_union(vertices_to_recheck, vertices_to_recheck, filled_neighbors_of_vx_to_fill)
    #                vertices_to_recheck.update((neighbors_dict[vertex_to_fill].intersection(filled_set)) - frozenset([vertex]))
                
                    bitset_add(filled_set, vertex_to_fill)
        bitset_copy(vertices_to_check, vertices_to_recheck)

    bitset_free(filled_set)
    bitset_free(vertices_to_check)
    bitset_free(filled_neighbors)
    bitset_free(unfilled_neighbors)
    bitset_free(vertices_to_recheck)
    bitset_free(filled_neighbors_of_vx_to_fill)
        
        
        #        bitset_copy(vertices_to_check, vertices_to_recheck)
    return 100
#    return