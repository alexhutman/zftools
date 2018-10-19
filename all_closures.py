from sage.all import *

def calculate_all_closures(ourGraph):
    
    print "vertices :", ourGraph.vertices()
    
    num_vertices = ourGraph.num_verts()
    
    neighbors_dict = {}
    for i in ourGraph.vertices():
        neighbors_dict[i] = frozenset(ourGraph.neighbors(i)) 
    
    for S in Subsets(ourGraph.vertices()):
        extend_closure(num_vertices, neighbors_dict, Set([]), S)
        
def extend_closure(num_verts, neighbors_dict, initially_filled_subset, vxs_to_add):
    filled_set = set(initially_filled_subset.union(vxs_to_add))

    vertices_to_check = set(vxs_to_add)

    for v in vxs_to_add:
        vertices_to_check.update(neighbors_dict[v].intersection(filled_set))

#        return graph.close_subset_under_forcing(filled_set)

    vertices_to_recheck = set()
    while vertices_to_check:
        #print "now will check", vertices_to_check
        vertices_to_recheck.clear()
        for vertex in vertices_to_check:
            #graph.num_vertices_checked += 1

            filled_neighbors = neighbors_dict[vertex].intersection(filled_set)
            unfilled_neighbors = neighbors_dict[vertex] - filled_neighbors
            if len(unfilled_neighbors) == 1:
                vertex_to_fill = next(iter(unfilled_neighbors))
                vertices_to_recheck.add(vertex_to_fill)
                #print vertex, "forces", vertex_to_fill
                #print filled_set, "filled set"
                #print vertices_to_check, "vertices to czech"
                #print vertices_to_recheck, "vertices to reczech"
                vertices_to_recheck.update((neighbors_dict[vertex_to_fill].intersection(filled_set)) - frozenset([vertex]))
                filled_set.add(vertex_to_fill)
        vertices_to_check = copy(vertices_to_recheck)
    return filled_set