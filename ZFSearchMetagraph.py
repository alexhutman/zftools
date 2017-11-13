from sage.all import *

# Define metagraph class in Python
class ZFSearchMetagraph:
    
    def __init__(self, graph_for_zero_forcing):
        self.primal_graph = graph_for_zero_forcing
        self.degree_list = graph_for_zero_forcing.degree()
        self.vertices_set = set(graph_for_zero_forcing.vertices())
        self.neighbors_dict = {}
        for i in self.vertices_set:
            self.neighbors_dict[i] = frozenset(graph_for_zero_forcing.neighbors(i))
        
        # member below is just for profiling purposes!
        self.num_vertices_checked = 0
    
    def close_subset_under_forcing(self, initially_filled_subset):
        all_vertices = list(self.vertices_set)
        filled_set = initially_filled_subset
        vertices_to_check = set(filled_set)
        
        vertices_to_recheck = set();
        while vertices_to_check:
            #print "now will check", vertices_to_check
            vertices_to_recheck.clear()
            for vertex in vertices_to_check:
                self.num_vertices_checked += 1
                
                filled_neighbors = self.neighbors_dict[vertex].intersection(filled_set)
                unfilled_neighbors = self.neighbors_dict[vertex] - filled_neighbors
                if len(unfilled_neighbors) == 1:
                    vertex_to_fill = next(iter(unfilled_neighbors))
                    vertices_to_recheck.add(vertex_to_fill)
                    #print vertex, "forces", vertex_to_fill
                    #print filled_set, "filled set"
                    #print vertices_to_check, "vertices to czech"
                    #print vertices_to_recheck, "vertices to reczech"
                    vertices_to_recheck.update((self.neighbors_dict[vertex_to_fill].intersection(filled_set)) - frozenset([vertex]))
                    filled_set.add(vertex_to_fill)
            vertices_to_check = copy(vertices_to_recheck)
        return filled_set
                    

    def close_subset_under_forcing_OLD(self, initially_filled_subset):
        all_vertices = list(self.vertices_set)
        filled_set = initially_filled_subset
        vertices_to_check = set(filled_set)
        
        new_filled_vertices_exist = True
        while new_filled_vertices_exist:
            new_filled_vertices_exist = False
            for current_vertex in all_vertices:
                if current_vertex in filled_set:
#                    ### see if this vertex can force
                    self.num_vertices_checked += 1

                    filled_neighbors = self.neighbors_dict[current_vertex].intersection(filled_set)
                    unfilled_neighbors = self.neighbors_dict[current_vertex] - filled_neighbors
                    if len(unfilled_neighbors) == 1:
                        new_vertex = next(iter(unfilled_neighbors))
                        filled_neighbors_new_vx = self.neighbors_dict[new_vertex].intersection(filled_set)
                        filled_set.add(new_vertex) #add newly filled vertex and its filled neighbors to filled_set
#                        for i in filled_neighbors_new_vx:
#                            filled_set.add(i)
                        new_filled_vertices_exist = True
                        all_vertices.remove(current_vertex) #we don't need to recheck the vertex that caused another to be filled (by def. it has 0 unfilled neighbors now)
        return filled_set
    
    def close_subset_under_forcing_OLDER(self, initially_filled_subset):
        # output: returns the set of vertices filled after iterating the forcing rule to completion
    
        all_vertices = self.vertices_set
        filled = list(initially_filled_subset) #list of currently filled vertices
        all_neighbors_filled = True
    
        for vertex in filled: # for every filled vertex
            neighbors_filled = self.neighbors_dict[vertex].intersection(filled)
            unfilled = self.neighbors_dict[vertex] - neighbors_filled # calculate which neighbors are unfilled
            if len(unfilled) == 1:              #if there's only one unfilled neighbor
                filled.append(unfilled.pop())   #fill that neighbor
            if set(filled) == all_vertices: #if all vertices are filled stop trying to fill vertices
                break

        for vertex in all_vertices: #if for every vertex, the amount of neighbors doesn't equal the amount of filled neighbors (i.e. not every neighbor is filled) set all_neighbors_filled to false
            if self.degree_list[vertex] != len(self.neighbors_dict[vertex].intersection(filled)):
                not all_neighbors_filled
        if not all_neighbors_filled: #keep trying until either every vertex is filled or there are no possible moves to make
            close_subset_under_forcing(filled)
        return filled
    
    def fill_one_vx_and_close(self, initially_filled_set, new_vx):
        all_vertices = list(self.vertices_set)
        filled_set = set(initially_filled_set)
        new_vx_filled_neighbors = self.neighbors_dict[new_vx].intersection(filled_set)
        vertices_to_check = set([new_vx]).union(new_vx_filled_neighbors)
        
        vertices_to_recheck = set();
        while vertices_to_check:
            #print "now will check", vertices_to_check
            vertices_to_recheck.clear()
            for vertex in vertices_to_check:
                self.num_vertices_checked += 1
                
                filled_neighbors = self.neighbors_dict[vertex].intersection(filled_set)
                unfilled_neighbors = self.neighbors_dict[vertex] - filled_neighbors
                if len(unfilled_neighbors) == 1:
                    vertex_to_fill = next(iter(unfilled_neighbors))
                    vertices_to_recheck.add(vertex_to_fill)
#                    print vertex, "forces", vertex_to_fill
#                    print filled_set, "filled set"
#                    print vertices_to_check, "vertices to czech"
#                    print vertices_to_recheck, "vertices to reczech"
                    vertices_to_recheck.update((self.neighbors_dict[vertex_to_fill].intersection(filled_set)) - frozenset([vertex]))
#                    print list(vertices_to_recheck), "vertices to reczech-post"
                    filled_set.add(vertex_to_fill)
            vertices_to_check = copy(vertices_to_recheck)
#            print vertices_to_check, "vertices to check - post"
        return filled_set
    
    def neighbors_with_edges(self, meta_vertex):
        # verify that 'meta_vertex' is actually a subset of the vertices
        # of self.primal_graph, to be interpreted as the filled subset
        list_of_neighbors = set() #Set of lists of vertices (neighbors of the graph with initially filled vertices of meta_vertex)

        print "neighbors requested for ", list(meta_vertex)

        set_of_neighbors_with_edges = set()

        set_of_all_primal_vertices = self.vertices_set
        cardinality_of_neighbor_set = 0

        initially_unfilled_set = set_of_all_primal_vertices - set(meta_vertex) # compute unfilled set
        candidate_set = initially_unfilled_set.copy()

        for new_vx_to_fill in initially_unfilled_set: # for each vertex that wasn't already filled...
            if new_vx_to_fill not in candidate_set:
                continue;
#            current_closure = self.some_method(meta_vertex, new_vx_to_fill)  #add just new_vx_to_fill to set meta_vertex and then close
            
            filled_in_set_current = set(meta_vertex) # ...store copy of original filled set...
            filled_in_set_current.add(new_vx_to_fill) # ..then fill in that one vertex to get new filled set

            # close this new filled set under forcing
            current_closure = frozenset(self.fill_one_vx_and_close(filled_in_set_current, new_vx_to_fill))
            candidate_set = candidate_set - current_closure
            list_of_neighbors.add(current_closure)
            if len(list_of_neighbors) > cardinality_of_neighbor_set:
                tuple_of_neighbor_with_edge = (current_closure, new_vx_to_fill)
                set_of_neighbors_with_edges.add(tuple_of_neighbor_with_edge)

                cardinality_of_neighbor_set += 1

        print "neighbors found as", list(set_of_neighbors_with_edges)
        return set_of_neighbors_with_edges