"""
This code is just an attempt to do something in Sage with graphs that can run compiled using Cython and the appropriate libraries.
"""


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
	
	# eventually call something like the below
	# create pointer to bitset array with neighborhoods
	# call cython code and pass it number of vertices and
	# list of their neighborhoods
	# result = do_compiled_stuff_with_graph(n, neighborhood_bitsets)
	# return result
	