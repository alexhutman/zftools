import sys
include "sage/data_structures/bitset.pxi"

list_to_check = [1,2,99999]

cdef bitset_t test_cython_bitset
test_python_bitset = Bitset(list_to_check)
test_python_set = set(list_to_check)

bitset_init(test_cython_bitset, max(list_to_check)+1)
for i in list_to_check:
    bitset_add(test_cython_bitset, i)

print "----- Sanity Check Commencing: -----"
print "Cython bitset:", bitset_list(test_cython_bitset)
print "Python bitset:", list(test_python_bitset)
print "Python set:", list(test_python_set)


print "\n", "Size of Cython bitset:", sizeof(test_cython_bitset)
print "Size of Python bitset:", sys.getsizeof(test_python_bitset)
print "Size of Python set:", sys.getsizeof(test_python_set)