import ZFSearchMetagraphNewAlgPostClose

def calculate_all_closures(metagraph):
    ourGraph = metagraph.primal_graph
    
    print "vertices :", ourGraph.vertices()
    
    for S in Subsets(ourGraph.vertices()):
        metagraph.extend_closure(S,Set([]))
