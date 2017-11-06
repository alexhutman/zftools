import Queue

def BFS_shortest_path_with_edge_labels(G, start_vertex, end_vertex, numVertices):
    # Input: G is a graph, start_vertex and end_vertex are vertices
    # Output: a list of vertices, in order, forming a shortest path from start to end
    # Implementation: some sort of BFS thing using a queue
    start = FrozenBitset(capacity=numVertices)
    end = FrozenBitset(Bitset(end_vertex).union(Bitset(capacity=numVertices)))
    
    zero_Bitset = FrozenBitset(capacity=numVertices)
    
    meta_vertices = [] #OUTPUT JUST THE META VERTICES RETURN LATER
    added_vertices = [] #OUTPUT JUST ADDED VERTICES RETURN LATER
    

    vertices_to_visit_queue   = Queue.Queue()
    visited_list              = ChainedList()
    shortest_path             = [] # Initialize a list for the path to be returned at the end

    # line below is just for profiling purposes!
    G.num_vertices_checked = 0
    
    vertices_to_visit_queue.put(start)
    visited_list.add_with_parent_and_edge(start,zero_Bitset,zero_Bitset)

    while not vertices_to_visit_queue.empty():
        curVertex = vertices_to_visit_queue.get()
        for vertex_edge_pair in G.neighbors_with_edges(curVertex):
            vertex, edge = vertex_edge_pair

            if vertex not in visited_list:
                vertices_to_visit_queue.put(vertex)
                visited_list.add_with_parent_and_edge(vertex,curVertex,edge)

            if vertex == end:
                # Reached target vertex, so begin back-chaining the path now
                current_vertex = [end,zero_Bitset]
                at_start_of_path = False
                while not at_start_of_path:
                    shortest_path.append(current_vertex)
                    meta_vertices.append(current_vertex[0])
                    added_vertices.append(current_vertex[1])
                    previous_vertex = visited_list.get_parent(current_vertex[0])
                    if previous_vertex[0]== zero_Bitset:
                        at_start_of_path = True
                    else:
                        current_vertex = previous_vertex

                shortest_path.reverse() # Reverse the path to get the correct traversal order
                added_vertices.remove(zero_Bitset)
                meta_vertices.reverse()
                added_vertices.reverse()
                return meta_vertices, added_vertices
            
            
def BFS_shortest_path_with_edge_labels_OLD(G, start_vertex, end_vertex):
    # Input: G is a graph, start_vertex and end_vertex are vertices
    # Output: a list of vertices, in order, forming a shortest path from start to end
    # Implementation: some sort of BFS thing using a queue
    start = frozenset(start_vertex)
    end = frozenset(end_vertex)
    
    meta_vertices = [] #OUTPUT JUST THE META VERTICES RETURN LATER
    added_vertices = [] #OUTPUT JUST ADDED VERTICES RETURN LATER
    

    vertices_to_visit_queue   = Queue.Queue()
    visited_list              = ChainedList()
    shortest_path             = [] # Initialize a list for the path to be returned at the end

    # line below is just for profiling purposes!
    G.num_vertices_checked = 0
    
    vertices_to_visit_queue.put(start)
    visited_list.add_with_parent_and_edge(start,None,None)
    
    while not vertices_to_visit_queue.empty():
        curVertex = vertices_to_visit_queue.get()
        for vertex_edge_pair in G.neighbors_with_edges(curVertex):
            vertex, edge = vertex_edge_pair

            if vertex not in visited_list:
                vertices_to_visit_queue.put(vertex)
                visited_list.add_with_parent_and_edge(vertex,curVertex,edge)

            if vertex == end:
                # Reached target vertex, so begin back-chaining the path now
                current_vertex = [end,None]
                at_start_of_path = False
                while not at_start_of_path:
                    shortest_path.append(current_vertex)
                    meta_vertices.append(current_vertex[0])
                    added_vertices.append(current_vertex[1])
                    previous_vertex = visited_list.get_parent(current_vertex[0])
                    if previous_vertex[0]== None:
                        at_start_of_path = True
                    else:
                        current_vertex = previous_vertex

                shortest_path.reverse() # Reverse the path to get the correct traversal order
                added_vertices.remove(None)
                meta_vertices.reverse()
                added_vertices.reverse()
                return meta_vertices, added_vertices