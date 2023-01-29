import pytest

from contextlib import contextmanager
from sage.all import graphs
from zeroforcing.metagraph import ZFSearchMetagraph
from test.wavefront import zero_forcing_set_wavefront # Make optional?


GRAPHS_TO_TEST = [
        graphs.BrinkmannGraph(),
        graphs.BrinkmannGraph().line_graph(),
        graphs.ClebschGraph(),
        graphs.ClebschGraph().line_graph(),
        graphs.CompleteGraph(16),
        graphs.CoxeterGraph(),
        graphs.CoxeterGraph().line_graph(),
        graphs.CubeGraph(5),
        graphs.DesarguesGraph(),
        graphs.DodecahedralGraph(),
        graphs.HeawoodGraph(),
        graphs.HoffmanGraph(),
        graphs.HoffmanGraph().complement(),
        graphs.MycielskiGraph(6),
        graphs.PaleyGraph(17),
        graphs.PaleyGraph(17).line_graph(),
        graphs.PaleyGraph(73),
        graphs.PathGraph(30),
        graphs.PetersenGraph(),
        graphs.RandomTree(22),
        graphs.RobertsonGraph(),
        graphs.RobertsonGraph().line_graph(),
        graphs.StarGraph(4),
        ]

class DijkstraTest:
    all_unfilled = frozenset()
    def __init__(self, graph):
        self.graph = graph
        self.metagraph = ZFSearchMetagraph(graph)
        self.all_filled = self.metagraph.to_relabeled_metavertex(graph.vertices(sort=False))
        self.wavefront_zf_number, self.wavefront_zf_set, _, _ = zero_forcing_set_wavefront(graph)

    def force_zeroly(self, relabelled_start_metavertex):
        relabeled_graph = self.graph.relabel(inplace=False)
        currently_filled = set(relabelled_start_metavertex)

        prev_length = -1
        cur_length = len(currently_filled)
        while cur_length != prev_length:
            vertices_to_add = set()
            for filled_vertex in currently_filled:
                unfilled_neighbors = set(relabeled_graph.neighbors(filled_vertex)).difference(currently_filled)
                if len(unfilled_neighbors) == 1:
                    vertices_to_add.add(unfilled_neighbors.pop())
            currently_filled.update(vertices_to_add)

            prev_length = cur_length
            cur_length = len(currently_filled)

        return currently_filled

@contextmanager
def profiler_enabled(p):
    # Stupid hack to be able to call `with` around a code block and only profile if it's enabled
    # Setup
    should_profile = p is not None
    if should_profile:
        p.enable()

    yield 

    # Teardown
    if should_profile:
        p.disable()

@pytest.mark.parametrize("graph,testcase", [
    pytest.param(
        graph, DijkstraTest(graph), id=str(graph)
    ) for graph in map(lambda g: g.copy(immutable=True), GRAPHS_TO_TEST)
    ])
def test_all_graphs(graph, testcase, profiler):
    # Doesn't test that it's the MINIMUM forcing set, but it at least tests that they are indeed forcing sets :)

    with profiler_enabled(profiler):
        zf_set = testcase.metagraph.dijkstra(testcase.all_unfilled, testcase.all_filled)
    
    zf_set_relabeled = testcase.metagraph.to_relabeled_metavertex(zf_set)
    forced_to_completion = testcase.force_zeroly(zf_set_relabeled)

    assert forced_to_completion == testcase.all_filled
    assert testcase.force_zeroly(testcase.wavefront_zf_set) == testcase.all_filled
    assert len(zf_set) == testcase.wavefront_zf_number

def main():
    pass

if __name__ == "__main__":
    main()
