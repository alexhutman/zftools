import pytest

from sage.data_structures.bitset import FrozenBitset
from zeroforcing.radix_tree import RadixTree

def test_radix_tree_insert_no_context():
    metavertices_so_far = FrozenBitset({1,2,3,5,9}) # 1000101110
    radix_tree = RadixTree(metavertices_so_far.capacity())
    radix_tree.insert(metavertices_so_far)

    # Yes, this looks dumb but is good for explicit testing. Can maybe write a method that traverses the RadixTree based on an input of the binary string we want to test (e.g. end = traverse('1000101110') ?)
    end = radix_tree.start.zero.one.one.one.zero.one.zero.zero.zero.one
    assert end.zero is None and end.one is None
    assert end.context is None

def test_radix_tree_insert_with_context():
    metavertices_so_far = FrozenBitset({1,2,3,5,9}) # 1000101110
    context = (FrozenBitset({1,2,3,5}), 9)
    radix_tree = RadixTree(metavertices_so_far.capacity())

    radix_tree.insert(metavertices_so_far, context)
    # Same disclaimer as above :D
    end = radix_tree.start.zero.one.one.one.zero.one.zero.zero.zero.one

    assert end.zero is None and end.one is None
    assert end.context == context

def test_radix_tree_insert_lookahead_yields_same_node_no_context():
    # TODO: Make RadixTree constructor to initialize RadixTree with an insert?
    metavertices_so_far = FrozenBitset({1,3}) # 1010
    new_metavx = FrozenBitset({1,2,3}) # 1110
    radix_tree = RadixTree(metavertices_so_far.capacity())

    radix_tree.insert(metavertices_so_far)
    initial_end = radix_tree.start.zero.one.zero.one

    radix_tree.insert(new_metavx)
    new_end = radix_tree.start.zero.one.one.one

    assert initial_end.zero is None and initial_end.one is None
    assert initial_end.context is None
    assert new_end.zero is None and new_end.one is None
    assert new_end.context is None

    # This is really the only needed check. The above are sanity checks.
    assert initial_end is new_end


SUBSETS = (
        {1,2,3,5},
        {1,2,5},
        {9}
        )
@pytest.mark.parametrize(
    "subset",
    [
        pytest.param(FrozenBitset(subset), id=str(subset))
        for subset in map(FrozenBitset, SUBSETS)
    ],
)
def test_radix_tree_subset(subset):
    metavertices_so_far = FrozenBitset({1,2,3,5,9})
    radix_tree = RadixTree(metavertices_so_far.capacity())
    radix_tree.insert(metavertices_so_far)

    assert radix_tree.is_subset(subset)


def main():
    pass

if __name__ == "__main__":
    main()
