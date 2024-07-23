# Zero Forcing Number
This program calculates the zero forcing number (and set) of any graph. The zero forcing number is defined as follows:
>A subset S of initially infected vertices of a graph G is called forcing if we can infect the entire graph by iteratively applying the following process. At each step, any infected vertex which has a unique uninfected neighbour, infects this neighbour. The forcing number of G is the minimum cardinality of a forcing set in G"
- [Kalinowski, Kamčev, Sudakov](https://arxiv.org/abs/1705.10391) 

---

## Usage
### Install
`sage -pip install .`

### Test
`sage -pip install zeroforcing[test]`
* Installs the dependencies for testing
`sage --python3 setup.py wavefront`
* Builds the wavefront code for verification during tests
`sage -pip install .`
* Installs the wavefront code we just built
`sage --python3 -m pytest [-x]`
* `-x` flag makes pytest stop after the first failure
* `-h` flag will show a section called `Zero forcing options:`

### Import
`from zeroforcing.metagraph import zero_forcing_set`

## Running in Docker
1. Download Docker from the [Docker website](https://www.docker.com/)
2. Run `docker build -t zeroforcing .` in the directory this git repository is located in
3. Run `docker run --rm -it zeroforcing`
4. The package should be automatically installed inside of the container and Sage should be running. Have fun!
