from contextlib import contextmanager

import pytest

from sage.graphs.graph_generators import GraphGenerators
from test.verifiability.wavefront import zero_forcing_set_wavefront  # Make optional?
from zeroforcing.metagraph import ZFSearchMetagraph


GRAPHS_TO_TEST = [
    GraphGenerators.BrinkmannGraph(),
    GraphGenerators.BrinkmannGraph().line_graph(),
    GraphGenerators.ClebschGraph(),
    GraphGenerators.ClebschGraph().line_graph(),
    GraphGenerators.CompleteGraph(16),
    GraphGenerators.CoxeterGraph(),
    GraphGenerators.CoxeterGraph().line_graph(),
    GraphGenerators.CubeGraph(5),
    GraphGenerators.DesarguesGraph(),
    GraphGenerators.DodecahedralGraph(),
    GraphGenerators.HeawoodGraph(),
    GraphGenerators.HoffmanGraph(),
    GraphGenerators.HoffmanGraph().complement(),
    GraphGenerators.MycielskiGraph(6),
    GraphGenerators.PaleyGraph(17),
    GraphGenerators.PaleyGraph(17).line_graph(),
    GraphGenerators.PaleyGraph(73),
    GraphGenerators.PathGraph(30),
    GraphGenerators.PetersenGraph(),
    GraphGenerators.RandomTree(22),
    GraphGenerators.RobertsonGraph(),
    GraphGenerators.RobertsonGraph().line_graph(),
    GraphGenerators.StarGraph(4),
]


class DijkstraTest:
    all_unfilled = frozenset()

    def __init__(self, graph):
        self.graph = graph
        self.metagraph = ZFSearchMetagraph(graph)
        self.all_filled = self.metagraph.to_relabeled_metavertex(graph.vertices(sort=False))

    def calculate_wavefront_zf_set(self):
        _, wavefront_zf_set, _, _ = zero_forcing_set_wavefront(self.graph)
        return wavefront_zf_set

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
def profiler_enabled(prof):
    # Stupid hack to be able to call `with` around a code block and only profile if it's enabled
    # Setup
    should_profile = prof is not None
    if should_profile:
        prof.enable()

    yield

    # Teardown
    if should_profile:
        prof.disable()


@pytest.mark.parametrize(
    "testcase",
    [
        pytest.param(DijkstraTest(graph), id=str(graph))
        for graph in map(lambda g: g.copy(immutable=True), GRAPHS_TO_TEST)
    ],
)
def test_all_graphs(testcase, profiler):
    with profiler_enabled(profiler):
        zf_set = testcase.metagraph.dijkstra(testcase.all_unfilled, testcase.all_filled)

    zf_set_relabeled = testcase.metagraph.to_relabeled_metavertex(zf_set)
    forced_to_completion = testcase.force_zeroly(zf_set_relabeled)
    wavefront_zf_set = testcase.calculate_wavefront_zf_set()

    assert forced_to_completion == testcase.all_filled
    assert testcase.force_zeroly(wavefront_zf_set) == testcase.all_filled
    assert len(zf_set) == len(wavefront_zf_set)


def main():
    pass

if __name__ == "__main__":
    main()
