from sage.all import *

# Define metagraph class in Python
class ZFSearchMetagraphBITSET:
    
    def __init__(self, graph_for_zero_forcing):
        self.primal_graph = graph_for_zero_forcing
        self.degree_list = graph_for_zero_forcing.degree()
        self.num_vertices = graph_for_zero_forcing.num_verts()
        self.vertices_set = Bitset('1'*self.num_vertices)
        self.zero_bitset = Bitset(capacity=self.num_vertices)
        self.fr_zero_bitset = FrozenBitset(capacity=self.num_vertices)
        self.neighbors_dict = {}
        for i in self.vertices_set:
            self.neighbors_dict[i] = Bitset(graph_for_zero_forcing.neighbors(i)).union(self.zero_bitset)
        
        # member below is just for profiling purposes!
        self.num_vertices_checked = 0
        
    def zero_fr_bitset(self, desired_length):
        return FrozenBitset('0' * desired_length)

    
    def fill_one_vx_and_close(self, initially_filled_set, new_vx):
        all_vertices = self.vertices_set
        filled_set = Bitset(initially_filled_set).union(self.zero_bitset)
        new_vx_filled_neighbors = self.neighbors_dict[new_vx].intersection(filled_set)
        vertices_to_check = new_vx_filled_neighbors.union(Bitset([new_vx]).union(self.zero_bitset))
        
        vertices_to_recheck = Bitset(capacity=self.num_vertices);
        while not vertices_to_check.isempty():
            #print "now will check", list(vertices_to_check)
            vertices_to_recheck.clear()
            for vertex in set(vertices_to_check):
                self.num_vertices_checked += 1
                
                filled_neighbors = self.neighbors_dict[vertex].intersection(filled_set)
                unfilled_neighbors = self.neighbors_dict[vertex] - filled_neighbors
                if len(unfilled_neighbors) == 1:
                    vertex_to_fill = unfilled_neighbors.pop()
                    vertices_to_recheck.add(vertex_to_fill)
                    #print vertex, "forces", vertex_to_fill
                    #print list(filled_set), "filled set"
                    #print list(vertices_to_check), "vertices to czech"
                    #print list(vertices_to_recheck), "vertices to reczech"
                    vertices_to_recheck.update((self.neighbors_dict[vertex_to_fill].intersection(filled_set)) - Bitset([vertex]).union(self.zero_bitset))
                    filled_set.add(vertex_to_fill)
                vertices_to_check = copy(vertices_to_recheck)
        return filled_set
    
    
    def neighbors_with_edges(self, meta_vertex):
        # verify that 'meta_vertex' is actually a subset of the vertices
        # of self.primal_graph, to be interpreted as the filled subset
        list_of_neighbors = set() #Set of lists of vertices (neighbors of the graph with initially filled vertices of meta_vertex)

        set_of_neighbors_with_edges = set()

        set_of_all_primal_vertices = self.vertices_set
        cardinality_of_neighbor_set = 0

        initially_unfilled_set = set_of_all_primal_vertices - Bitset(meta_vertex).union(self.zero_bitset) # compute unfilled set
        candidate_set = copy(initially_unfilled_set)

        for new_vx_to_fill in set(initially_unfilled_set): # for each vertex that wasn't already filled...
            if new_vx_to_fill not in candidate_set:
                continue;
#            current_closure = self.some_method(meta_vertex, new_vx_to_fill)  #add just new_vx_to_fill to set meta_vertex and then close
            
            filled_in_set_current = Bitset(meta_vertex).union(self.zero_bitset) # ...store copy of original filled set...
            filled_in_set_current.add(new_vx_to_fill) # ..then fill in that one vertex to get new filled set

            # close this new filled set under forcing
            current_closure = FrozenBitset(self.fill_one_vx_and_close(filled_in_set_current, new_vx_to_fill))
            candidate_set = candidate_set - current_closure
            list_of_neighbors.add(current_closure)
            if len(list_of_neighbors) > cardinality_of_neighbor_set:
                tuple_of_neighbor_with_edge = (current_closure, new_vx_to_fill)
                set_of_neighbors_with_edges.add(tuple_of_neighbor_with_edge)

                cardinality_of_neighbor_set += 1

        return set_of_neighbors_with_edges

