import sage.graphs

def which_neighbors_filled(graph, vertex, filled_in_vertices):
    neighbors_filled = []
    for vertices in graph.neighbors(vertex):
        if vertices in filled_in_vertices:
            neighbors_filled.append(vertices)
    return neighbors_filled

def close_subset_under_forcing(G, initially_filled_subset):
    # input: G is a graph, initially_filled_subset is set of vertices
    # output: derived_set is the set of vertices filled after iterating the forcing rule to completion
    
    degree_list = G.degree()
    
    all_vertices = G.vertices()
#    G.show(save_pos=True) #display the graph with no vertices filled in
    filled = initially_filled_subset[:] #list of currently filled vertices
#    display_graph(G, initially_filled_subset) #display graph with the initially filled subset
    all_neighbors_filled = True
    
    for vertex in filled: # for every filled vertex
        neighbors_filled = which_neighbors_filled(G, vertex, filled) #calculate which neighbors are filled
        unfilled = (set(G.neighbors(vertex))-set(neighbors_filled)) #calculate which neighbors are unfilled
        if len(unfilled) == 1:              #if there's only one unfilled neighbor
            filled.append(unfilled.pop())   #fill that neighbor
#            display_graph(G, filled) #if new vertex is filled in, display graph
        if set(filled) == set(all_vertices): #if all vertices are filled stop trying to fill vertices
            break
    for vertex in all_vertices: #if for every vertex, the amount of neighbors doesn't equal the amount of filled neighbors (i.e. not every neighbor is filled) set all_neighbors_filled to false
        if degree_list[vertex] != len(which_neighbors_filled(G,vertex, filled)):
            not all_neighbors_filled
    if not all_neighbors_filled: #keep trying until either every vertex is filled or there are no possible moves to make
        close_subset_under_forcing(G,filled)
    #filled.sort() #sorts vertices if desired. without this line, however, the initially filled vertices are the first in the returned list.
    return filled