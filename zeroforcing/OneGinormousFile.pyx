# cython: profile=False

from sage.graphs.all import Graph

from sage.data_structures.bitset cimport (
    Bitset,
    FrozenBitset
)

from zeroforcing.fastqueue.fastqueue import FastQueueForBFS
from zeroforcing.metagraph.metagraph cimport ZFSearchMetagraph


import itertools
import random
from sage.data_structures.bitset import Bitset, FrozenBitset


DijkstraMG = None

def shortest(v, path_so_far, predecessor_list, start):
    predecessor_of_v = predecessor_list[v]
    path_so_far.insert(0,predecessor_of_v)
    
    if predecessor_of_v[0] != start:
        shortest(predecessor_of_v[0], path_so_far, predecessor_list, start)
    return path_so_far

def build_zf_set(final_metavx_list):
    global DijkstraMG #To access the graph's neighbors

    zf_set = set()

    for (filled_vertices, forcing_vx) in final_metavx_list[:-1]: #Do not need to do the last metavertex (everything is already filled)
        if forcing_vx not in filled_vertices: #If filled, don't need to add it to zf_set since it will already have been gotten for free
            zf_set.add(forcing_vx)
#        filled_set.add(forcing_vx) #Fill forcing vertex
        unfilled_neighbors = DijkstraMG.neighbors_dict[forcing_vx] - filled_vertices #Find n unfilled neighbors of forcing vertex
    
        if len(unfilled_neighbors)-1 > 0:
            zf_set.update(set(itertools.islice(unfilled_neighbors, len(unfilled_neighbors)-1))) #Pick n-1 of them, the last will be gotten for free
#        filled_set.update(DijkstraMG.neighbors_dict[forcing_vx]) #Fill all of the neighbors
    return zf_set

def dijkstra(metagraph, start, target):
    return real_dijkstra(metagraph, start, target)

cdef real_dijkstra(ZFSearchMetagraph metagraph, start, target):
    global DijkstraMG
    DijkstraMG = metagraph

    #cdef Bitset previous_closure
    #cdef Bitset vx_and_neighbors
    
#    cdef frozenset current

    cdef dict previous
#    cdef list unvisited_queue
    
    cdef int current_distance
    cdef int cost_of_making_it_force
    cdef int what_forced
    cdef int new_dist
    
    cdef int num_vertices_primal_graph

    num_vertices_primal_graph = metagraph.num_vertices
    
    empty_FrozenBitset = FrozenBitset()
    
    previous = {}
#    unvisited_queue = [(0, start, None)]
    unvisited_queue = FastQueueForBFS(num_vertices_primal_graph)
    
    start_FrozenBitset = FrozenBitset(start, capacity=num_vertices_primal_graph)
    target_FrozenBitset = FrozenBitset(target, capacity=num_vertices_primal_graph)
    
    unvisited_queue.push( 0, (start_FrozenBitset, None) )
#    heapq.heapify(unvisited_queue)

    done = False
    while not done:
#        uv = heapq.heappop(unvisited_queue)
        current_distance, uv = unvisited_queue.pop_and_get_priority()
        
#        current_distance = uv[0]
        parent = uv[0]
        vx_that_is_to_force = uv[1]

        previous_closure = parent
#        test_capacity = max(parent)+1 if len(parent) > 0 else 1
#        previous_closure.update(Bitset(parent, capacity=test_capacity))

        if vx_that_is_to_force != None:
            current = metagraph.extend_closure(previous_closure, metagraph.closed_neighborhood_list[vx_that_is_to_force])
        else:
            current = empty_FrozenBitset
        
        if current in previous:
            continue

#        superset_has_been_visited = False
#        for seen_set in previous:
#            if current.issubset(seen_set):
#                superset_has_been_visited = True
#                break
#        if superset_has_been_visited:
#            print "yay"
#            continue
            
            
        previous[current] = (parent, vx_that_is_to_force)

        if current == target_FrozenBitset: # We have found the target vertex, can stop searching now
            done = True
            break
        
        metagraph.neighbors_with_edges_add_to_queue(current, unvisited_queue, current_distance)
            
    temp = [(target_FrozenBitset, None)]
    shortest_path = shortest(target_FrozenBitset, temp, previous, start_FrozenBitset)

    print("Closures remaining on queue:", len(unvisited_queue))
    print("Length of shortest path found in metagraph:", len(shortest_path))
#    print "Shortest path found: ", shortest_path

    
    return build_zf_set(shortest_path)