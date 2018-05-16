"""
This code is just an attempt to do something in Sage with graphs that can run compiled using Cython and the appropriate libraries.
"""

from sage.graphs.all import Graph 
include "sage/data_structures/bitset.pxi"
           


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
	
	print "This is a graph!"
	
	num_vertices = graph.num_verts()
	
	# create pointer to bitset array with neighborhoods
	cdef bitset_s *neighborhood_array = <bitset_s *> sage_malloc(num_vertices*sizeof(bitset_s))
	for v in range(num_vertices):
		bitset_init(&neighborhood_array[v], num_vertices)
		bitset_clear(&neighborhood_array[v])
		for w in graph.neighbors(v):
			bitset_add(&neighborhood_array[v], w)

	result = do_compiled_stuff_with_graph(num_vertices, neighborhood_array)
	# return result


cdef do_compiled_stuff_with_graph(int n, bitset_s *neighborhood_bitsets):
	cdef char* s = NULL

	print "Graph has", n, "vertices!"

	print "Here are the neighborhoods as bitsets:"
	for v in range(n):
		print bitset_chars(s, &neighborhood_bitsets[v])
#		print j
	return
	