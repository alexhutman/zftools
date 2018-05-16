import itertools
import heapq
import random

DijkstraMG = None

def shortest(v, path_so_far, predecessor_list):
    predecessor_of_v = predecessor_list[v]
    if predecessor_of_v[0] != None:
        path_so_far.insert(0,predecessor_of_v)
        shortest(predecessor_of_v[0], path_so_far, predecessor_list)
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
    global DijkstraMG
    DijkstraMG = metagraph

    previous = {}
    unvisited_queue = [(0, start, None, None)]
    heapq.heapify(unvisited_queue)

    done = False
    while not done:
        uv = heapq.heappop(unvisited_queue)
#        print "just popped", uv
        
        current_distance = uv[0]
        current_pre_closure = uv[1]
        parent = uv[2]
        vx_that_is_to_force = uv[3]

#        vx_and_neighbors = set(parent) if parent != None else set([])
#        if vx_that_is_to_force != None:
#            vx_and_neighbors = vx_and_neighbors.union(set(metagraph.neighbors_dict[vx_that_is_to_force])).union(set([vx_that_is_to_force]))
#        current = frozenset(metagraph.close_subset_under_forcing(vx_and_neighbors))

        previous_closure = set(parent) if parent != None else set([])
        vx_and_neighbors = set([])
        if vx_that_is_to_force != None:
            vx_and_neighbors = set([vx_that_is_to_force])
            vx_and_neighbors.update(set(metagraph.neighbors_dict[vx_that_is_to_force]))
        current = frozenset(metagraph.extend_closure(previous_closure, vx_and_neighbors))


#        print "closure calculated as", current
        
#        print "result of forcing on",vx_and_neighbors ,"after forcing", current
        
        # whether vertex is in 'previous' is proxy for if it has been visited
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
#        print "stored", parent, "as predecessor of", current

        if current == target: # We have found the target vertex, can stop searching now
            done = True
#            break
            
#        print "visiting", current, "from predecessor", previous[current]

        for neighbor_tuple in metagraph.neighbors_with_edges(current):
#            print "neighbor of", current, ":", neighbor_tuple, "with cost", neighbor_tuple[0]
            next_vx = neighbor_tuple[2]
            what_forced = neighbor_tuple[1]
            cost_of_making_it_force = neighbor_tuple[0]
            
#            if next_vx in previous:
#                continue
            new_dist = current_distance + cost_of_making_it_force
            
            heapq.heappush(unvisited_queue, (new_dist, next_vx, current, what_forced) )
            
            #print "Pushing: ", (next_vx, new_dist, current, what_forced)
        
#        print "queue before next pop", unvisited_queue

    temp = [(target, None)]
#    print "previous: ..."
#    print previous
    shortest_path = shortest(target, temp, previous)
    print shortest_path
    return build_zf_set(shortest_path)