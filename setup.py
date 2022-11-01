import sys

from distutils.core import setup
from distutils.extension import Extension
from pathlib import Path

from Cython.Distutils import build_ext
from Cython.Build import cythonize


SAGE_PATH = Path("/home/alex/projects/python/sage/src/")
BITSET_PATH_NO_EXT = SAGE_PATH / "sage" / "data_structures" / "bitset"

bitset_base = Extension('sage.data_structures.bitset_base',
        sources=[str(BITSET_PATH_NO_EXT.with_name('bitset').with_suffix('.pyx'))],
        include_dirs=[
            str(SAGE_PATH / "sage" / "cpython"),
            "/home/alex/projects/python/sage/local/var/lib/sage/venv-python3.10.5/lib/python3.10/site-packages/cysignals"
            ]
        )
bitset = Extension('sage.data_structures.bitset', sources=[str(BITSET_PATH_NO_EXT.with_suffix('.pyx'))])
fastqueue = Extension('zeroforcing.fastqueue', sources=['zeroforcing/fastqueue/*.pyx'])
metagraph = Extension(
        'zeroforcing.metagraph',
        sources=['zeroforcing/metagraph/*.pyx'],
        include_dirs=[
            "/home/alex/projects/python/sage/local/var/lib/sage/venv-python3.10.5/lib/python3.10/site-packages/cysignals"
            ]
        )

setup(
        include_dirs=["include", SAGE_PATH],
        name='zeroforcing',
        packages=['sage.data_structures.bitset_base', 'sage.data_structures.bitset', 'zeroforcing.fastqueue'],
        #package_data={"sage.data_structures.bitset": ['include/sage/data_structures/*.pxd']},
        cmdclass={'build_ext': build_ext},
        ext_modules=cythonize(
            #[bitset_base, bitset, fastqueue, metagraph],
            [bitset_base, bitset, fastqueue],
            compiler_directives={'language_level' : "3"}
            )
)
