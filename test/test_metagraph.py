import unittest
import sys

from sage.all import *
from zeroforcing.metagraph import ZFSearchMetagraph


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

def force_zeroly(graph, relabelled_start_metavertex):
    relabeled_graph = graph.relabel(inplace=False)
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


class TestDijkstra(unittest.TestCase):
    # Doesn't test that it's the MINIMUM forcing set, but it at least tests that they are indeed forcing sets :)
    def test_zero_forcing(self):
        all_unfilled = frozenset()
        for graph in GRAPHS_TO_TEST:
            with self.subTest("Testing graph", graph=str(graph)):
                metagraph = ZFSearchMetagraph(graph)
                all_filled = metagraph.to_relabeled_metavertex(graph.vertices(sort=False))

                zf_set = metagraph.dijkstra(all_unfilled, all_filled)
                zf_set_relabeled = metagraph.to_relabeled_metavertex(zf_set)

                forced_to_completion = force_zeroly(graph, zf_set_relabeled)
                self.assertEqual(forced_to_completion, all_filled)

if __name__ == "__main__":
    runner = unittest.TextTestRunner(verbosity=2)
    unittest.main(testRunner=runner)
