from sage.all import *

# Define metagraph class in Python
class ZFSearchMetagraphNewAlg:

    def __init__(self, graph_for_zero_forcing):
        cdef int num_vertices
        
        self.primal_graph = graph_for_zero_forcing
        self.degree_list = graph_for_zero_forcing.degree()
        self.vertices_set = set(graph_for_zero_forcing.vertices())
        self.neighbors_dict = {}
        
        self.num_vertices = len(self.vertices_set)
        
        for i in self.vertices_set:
            self.neighbors_dict[i] = frozenset(graph_for_zero_forcing.neighbors(i))

        # member below is just for profiling purposes!
        self.num_vertices_checked = 0

    def extend_closure(self, initially_filled_subset, vxs_to_add):
        all_vertices = list(self.vertices_set)
        filled_set = set(initially_filled_subset.union(vxs_to_add))

        vertices_to_check = set(vxs_to_add)
        
        if self.num_vertices < 30:
            print "ok"
        
        for v in vxs_to_add:
            vertices_to_check.update(self.neighbors_dict[v].intersection(filled_set))
        
#        return self.close_subset_under_forcing(filled_set)
            
        vertices_to_recheck = set()
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

    def close_subset_under_forcing(self, initially_filled_subset):
        all_vertices = list(self.vertices_set)
        filled_set = initially_filled_subset
        vertices_to_check = set(filled_set)

        vertices_to_recheck = set()
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
            vertices_to_check.clear()
            vertices_to_check.update(vertices_to_recheck)
        return filled_set

    def calculate_cost(self, meta_vertex, vertex_to_calc_cost):
        unfilled_neighbors = set(self.neighbors_dict[vertex_to_calc_cost])
        unfilled_neighbors = unfilled_neighbors - meta_vertex
        numUnfilledNeighbors = len(unfilled_neighbors)
        accounter = None

        if numUnfilledNeighbors == 0:
            accounter = 0
        else:
            accounter = 1

        cost = numUnfilledNeighbors - accounter

        if vertex_to_calc_cost not in meta_vertex:
            cost = cost + 1

        return cost


    def neighbors_with_edges(self, meta_vertex):
        # verify that 'meta_vertex' is actually a subset of the vertices
        # of self.primal_graph, to be interpreted as the filled subset
        #print "neighbors requested for ", list(meta_vertex)

        set_of_neighbors_with_edges = set()

#------------------------------------------------------------------------------------------------------------------------------

        for new_vx_to_make_force in self.vertices_set:
#            vx_and_neighbors = set([new_vx_to_make_force]).union(set(self.neighbors_dict[new_vx_to_make_force])).union(meta_vertex)
#            current_closure = frozenset(self.close_subset_under_forcing(vx_and_neighbors))
            cost = self.calculate_cost(meta_vertex, new_vx_to_make_force)
            if cost > 0:
                tuple_of_neighbor_with_edge = (cost, new_vx_to_make_force)
                set_of_neighbors_with_edges.add(tuple_of_neighbor_with_edge)
        return set_of_neighbors_with_edges

