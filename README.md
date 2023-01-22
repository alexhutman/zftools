# Zero Forcing Number
This program calculates the zero forcing number (and set) of any graph. The zero forcing number is defined as follows: "A subset S of initially infected vertices of a graph G is called forcing if we can infect the entire graph by iteratively applying the following process. At each step, any infected vertex which has a unique uninfected neighbour, infects this neighbour. The forcing number of G is the minimum cardinality of a forcing set in G," according to [Kalinowski, Kamčev, and Sudakov](https://arxiv.org/abs/1705.10391). 

---

## Usage:
### Build:
`sage --python3 setup.py build_ext`

### Test:
`sage --python3 -m pytest [-x]`
* `-x` flag makes pytest stop after the first failure
* `-h` flag will show a section called `Zero forcing options:`

### Clean:
`sage --python3 setup.py clean`

### Help:
`sage --python3 setup.py -h`
(You can also use the `-h` flag in subcommands. i.e. `sage --python3 setup.py build_ext -h`

