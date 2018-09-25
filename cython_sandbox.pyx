"""
This code is just an attempt to do something in Sage with graphs that can run compiled using Cython and the appropriate libraries.
"""


"""
	RELEVANT REFERENCE PAGES:
		:: for the original Sage bitset interface to Cython by Robert B
		https://github.com/sagemath/sagelib/blob/master/sage/misc/bitset.pxi
		:: for basic Cython bitset types written into Sage
		https://sage.math.leidenuniv.nl/src/data_structures/bitset.pxd
		:: for the Python wrapper for these written by Jason
		https://github.com/sagemath/sagelib/blob/master/sage/misc/bitset.pyx
"""

from sage.graphs.all import Graph 
from sage.data_structures.bitset cimport FrozenBitset, Bitset 
include "sage/data_structures/bitset.pxi"

import heapq
           


def compute_from_graph(graph):
	"""
	By using 'def' we are defining an ordinary Python function
	so this does NOT get compiled, and can therefore interact
	with Sage in the usual way.  (At least, I think so.)
	
	We want as much stuff as possible to run compiled, so let's
	try to set this up as a "staging" function, which takes the
	graph data and just creates raw bitsets to store the vertex
	neighborhoods.  Then any subsequent code just uses that
	data and so does not have to interact with Sage itself.
	"""
	
	# check to make sure the input is a graph
	if not isinstance(graph, Graph):
		# maybe there is a more formal way to throw an error?
		print "This is not a graph."
		return
	
	# maybe we should also verify that the vertex names are INTEGERS
	# (if not then call relabel or something)
	
	num_vertices = graph.num_verts()
	print "This is a graph with", num_vertices, "vertices!"
	
	# create pointer to bitset array with neighborhoods
	cdef bitset_s *neighborhood_array = <bitset_s*> sage_malloc(num_vertices*sizeof(bitset_s))
	for v in range(num_vertices):
		bitset_init(&neighborhood_array[v], num_vertices)
		bitset_clear(&neighborhood_array[v])
		for w in graph.neighbors(v):
			bitset_add(&neighborhood_array[v], w)

	result = do_compiled_stuff_with_graph(num_vertices, neighborhood_array)
	# return result


cdef do_compiled_stuff_with_graph(int n, bitset_s* neighborhood_array):
	cdef char* s = NULL

#	print "Graph has", n, "vertices!"

	# Now let's try to heapsort the vertices by degree, just for
	# something to do that uses a queue (hey that rhymes!)
	new_q = []
	for v in range(n):
		degree_of_v = bitset_len(&neighborhood_array[v])
		heapq.heappush(new_q, (degree_of_v, v) )
	
	while len(new_q) > 0:
		degree, vertex = heapq.heappop(new_q);
#		print "Vertex", vertex, "has degree", degree

	# try finding the meta-graph neighbors of {1,2,3} or something
	cdef bitset_t	initial_closure
	cdef bitset_t	new_vxs_to_closure
	
	bitset_init(initial_closure, n)
	bitset_clear(initial_closure,)
	bitset_init(new_vxs_to_closure, n)
	bitset_clear(new_vxs_to_closure)
	
	bitset_add(initial_closure, 4)
	bitset_add(initial_closure, 5)
	
	bitset_add(new_vxs_to_closure, 0)

#	print "Okay imagine {1,2,3} is filled.  Then..."

	new_closure = extend_closure_ordinary_ZF(n, neighborhood_array, initial_closure, new_vxs_to_closure)
	
	print "{4,5} plus 0 closes to", new_closure

	return

cdef list metaneighbors_ordinary_zf(int n, bitset_s* neighborhood_array, bitset_t neighbors_from_metavx):
	cdef bitset_t vxs_add_to_zf_set_to_reach_neighbor
	
	cdef bitset_t already_filled_set = neighbors_from_metavx
	cdef bitset_t currently_unfilled_set

	cdef bitset_t unfilled_neighbors_of_w

	#### BELOW WE ALLOCATE MEMORY SO WE HAVE TO REMEMBER TO FREE IT	
	bitset_init(unfilled_neighbors_of_w, n)
	bitset_init(currently_unfilled_set, n)
	bitset_init(vxs_add_to_zf_set_to_reach_neighbor, n)

	bitset_complement(currently_unfilled_set, already_filled_set)

	list_of_metavx_neighbors = []

	# for each vertex w
	for w in range(n):
		bitset_clear(vxs_add_to_zf_set_to_reach_neighbor)
		
		# if w is unfilled
		if not bitset_in(already_filled_set, w):
			# add w to set to be filled
			bitset_add(vxs_add_to_zf_set_to_reach_neighbor, w)
			
		# find all the unfilled neighbors of w
		bitset_intersection(unfilled_neighbors_of_w, currently_unfilled_set, &neighborhood_array[w])
		
		# if w has > 1 unfilled neighbor
		if bitset_len(unfilled_neighbors_of_w) > 1:
			# add all but one neighbor of w to set to be filled
			arbitrary_unfilled_neighbor = bitset_first(unfilled_neighbors_of_w)
			bitset_discard(unfilled_neighbors_of_w, arbitrary_unfilled_neighbor)
			
			### WARNING: CHECK TO SEE THAT IT IS OKAY FOR THE TARGET ARGUMENT
			### TO A BITSET METHOD TO BE THE SAME AS ONE OF THE OTHERS
			bitset_union(vxs_add_to_zf_set_to_reach_neighbor, vxs_add_to_zf_set_to_reach_neighbor, unfilled_neighbors_of_w)
			
		cost = bitset_len(vxs_add_to_zf_set_to_reach_neighbor)
		if cost > 0:
			new_neighbor_Bitset = FrozenBitset(capacity=n)
			# the code below is a 'hack' appearing in the wavefront code
			# to get data from a Cython bitset to a Sage (Python) object
			bitset_copy(&new_neighbor_Bitset._bitset[0], vxs_add_to_zf_set_to_reach_neighbor)
			list_of_metavx_neighbors.append( (w, new_neighbor_Bitset) )
		else:
			print "...vertex", w, "would have cost 0."
	
	# need to deallocate each bitset that was set up with bitset_init()
	bitset_free(unfilled_neighbors_of_w)
	bitset_free(currently_unfilled_set)
	bitset_free(vxs_add_to_zf_set_to_reach_neighbor)

	return list_of_metavx_neighbors





cdef list extend_closure_ordinary_ZF(int n, bitset_s* neighborhood_array, bitset_t previous_closure, bitset_t vxs_to_add):
	cdef bitset_t filled_vertices
	cdef bitset_t unfilled_vertices
	cdef bitset_t filled_neighbors
	cdef bitset_t unfilled_neighbors
	cdef bitset_t vxs_to_check
	cdef bitset_t vxs_to_recheck
	
	bitset_init(filled_vertices, n)
	bitset_init(unfilled_vertices, n)
	bitset_init(filled_neighbors, n)
	bitset_init(unfilled_neighbors, n)
	bitset_init(vxs_to_check, n)
	bitset_init(vxs_to_recheck, n)
	
	# initialize new filled set to originally filled plus new vertices
	bitset_union(filled_vertices, previous_closure, vxs_to_add)
	bitset_complement(unfilled_vertices, filled_vertices)
	
	# let recheck set be vertices to add...
	bitset_copy(vxs_to_recheck, vxs_to_add)
	
	# ...then add each filled neighbor
	# for neighborhood of each vertex to add
	i = 0
	while True:
		next_vx = bitset_next(vxs_to_add, i)
		i += 1
		if next_vx == -1:
			break

		# get its filled neighbors
		bitset_intersection(filled_neighbors, &neighborhood_array[next_vx], filled_vertices)
	
		# union with its filled neighbors
		bitset_union(vxs_to_recheck, vxs_to_recheck, filled_neighbors)

	
	# while vertices to recheck is not empty
	while not bitset_isempty(vxs_to_recheck):
		# vertices to check = vertices to recheck
		bitset_copy(vxs_to_check, vxs_to_recheck)
		bitset_clear(vxs_to_recheck)
		
		# for each vertex to check
		i = 0
		while True:
			next_vx = bitset_next(vxs_to_check, i)
			i += 1
			if next_vx == -1:
				break

			# verify it really is filled
			if not bitset_in(filled_vertices, next_vx):
				print "Attempt to check unfilled vertex for forcing!"
				break

			# count number of its unfilled neighbors
			bitset_intersection(unfilled_neighbors, &neighborhood_array[next_vx], unfilled_vertices)
			
			# if exactly one, fill that sucker in
			if bitset_len(unfilled_neighbors) == 1:
				if next_vx == 0:
					print "yay"
				lone_unfilled_neighbor = bitset_pop(unfilled_neighbors)
				bitset_add(filled_vertices, lone_unfilled_neighbor)
				bitset_remove(unfilled_vertices, lone_unfilled_neighbor)

				# add new filled guy and its filled neighbors to the recheck set
				bitset_intersection(filled_neighbors, &neighborhood_array[lone_unfilled_neighbor], filled_vertices)
				bitset_union(vxs_to_recheck, vxs_to_recheck, filled_neighbors)
				bitset_add(vxs_to_recheck, lone_unfilled_neighbor)
	
	new_closure_Bitset = FrozenBitset(capacity=n)
	# the code below is a 'hack' appearing in the wavefront code
	# to get data from a Cython bitset to a Sage (Python) object
	bitset_copy(&new_closure_Bitset._bitset[0], filled_vertices)
	
	bitset_free(filled_vertices)
	bitset_free(unfilled_vertices)
	bitset_free(filled_neighbors)
	bitset_free(unfilled_neighbors)
	bitset_free(vxs_to_check)
	bitset_free(vxs_to_recheck)
	
	return list(new_closure_Bitset)




	
