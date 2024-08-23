# zftools

### Purpose.
This software provides very fast calculation of zero forcing parameters.  Currently, it is able to compute only the “original” zero forcing parameter, namely the **zero forcing number of a finite simple graph**, originally defined by the “Special Graphs Working Group” that formed during a 2006 workshop at the American Institute of Mathematics (AIM) in their paper:

<ul>
AIM Minimum Rank – Special Graphs Work Group. <a href="https://doi.org/10.1016/j.laa.2007.10.009">Zero forcing sets and the minimum rank of graphs</a>. <i>Linear Algebra and its Applications</i>, 428(7):1628–1648 (2008)
</ul>

### Definition.
Given a finite graph, choose some vertices to be “filled” and then apply this rule repeatedly until it cannot be applied further: If any filled vertex has exactly one unfilled neighbor, then that neighbor becomes filled.  (We say that the first vertex “forces” its neighbor.)  The smallest number of vertices that can be initially filled so that all vertices become filled eventually is the **zero forcing number** of the graph.

### Method.
The algorithm applied finds the least weight of a path in a directed, weighted “metagraph” in which each vertex represents a subset of vertices in the primal graph *G* (the one whose zero forcing number is desired) with the property that, when this subset is precisely the set of filled vertices, no vertex can force.  An arc of weight *w* is present from *X* to *Y* when it is possible to add *w* vertices to the initially filled set that produced *X* to obtain an initially filled set that produces *Y*.  (That is, it is possible to expand the size of the ultimately filled set from *X* to *Y* at the “cost” of filling *w* additional vertices at the beginning.)  Then one can show that the smallest total weight of a directed path from &empty; to *V(G)* in this metagraph is the zero forcing number of *G*.

The advantage to the above formalism is that it allows the zero forcing number to be computed using any of the standard algorithms for finding a path of smallest weight in a weighted directed graph.  In particular, in this implementation we use Dijkstra's Algorithm.

### Capabilities and limitations.
The software is able to compute the zero forcing number very efficiently for most simple graphs.  Some graphs, such as stars, represent a weakness for the algorithm and may produce longer running times.  In addition, memory usage can be prodigious for very large graphs.  Steps are planned to address both of these limitations in the future.  For now, the algorithm is very quick for most graphs.  For example, for the Paley graph on 101 vertices, the zero forcing number can be computed in just a few seconds.


## How to install:
### Option 1: Install through PyPI
Type the line below into any cell in a SageMath Jupyter notebook:
```
%pip install zftools
```

Alternatively, type the following at the command line in any terminal session:
```bash
sage -pip install zftools
```

The package should download from PyPI and build using Cython. (If running on macOS, during the process you may be prompted to install the command line developer tools.  This is because installation involves compiling Cython code.)

### Option 2: Install from source
1. Either use `git` to clone the repository into the directory in which your SageMath Jupyter notebook resides, or follow these steps:
    1. Download the `.zip` file of the project from [the releases page](https://github.com/alexhutman/zftools/releases).
    2. Move the `.zip` file into the same directory as your SageMath Jupyter notebook.
    3. Into any cell in the notebook, execute this command:
        * ```
          !unzip zftools-master.zip
          ```

2. Execute this command:
    * ```
      %pip install .
      ```

### Option 3: Run from Docker
1. Obtain and install [Docker](https://www.docker.com/).
2. Run `docker build -t zftools .` in the directory this git repository is located in
    * You can specify `--build-arg ZF_BUILD_ARGS="--debug"` before the `-t` flag to build in debug mode
3. Run `docker run --rm -it zftools`
4. Follow the "How to use" section

## How to use:
Immediately after installation, you may need to restart the kernel before you can use the package.  (Try this if the command below does not work.)

Execute this command in any Sage cell:

```python3
from zftools import *
```

The functions `zero_forcing_set()` and `zero_forcing_number()` should now be available and can be applied to any Sage graph object.  For example:

```python3
G = graphs.PaleyGraph(61)
zero_forcing_set(G)
```

## Other stuff:
### Build:
1. Install the `build` module:
    * ```bash
      sage -pip install build
      ```

2. Build the project:
    * ```bash
      sage --python3 -m build --no-isolation .
      ```
      * The `--no-isolation` flag is needed because the `build` module builds in a virtual environment by default. We need access to Sage's packages and environment variables to build.

### Test:
1. Install the project, along with test dependencies:
    * ```bash
      COMPILE_WAVEFRONT=true sage -pip install .[test]
      ```
        * The `COMPILE_WAVEFRONT` flag enables compilation (and in this case, installation) of the wavefront code in order to verify our results.

2. Test the code:
    * ```bash
      sage --python3 -m pytest [-h]
      ```
        * `-h` flag will show more options, including a section called `Zero forcing options:`