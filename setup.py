from distutils.core import setup
from distutils.extension import Extension
from pathlib import Path

from Cython.Distutils import build_ext
from Cython.Build import cythonize


fastqueue = Extension(
        'zeroforcing.fastqueue',
        sources=['zeroforcing/fastqueue/*.pyx']
        )
metagraph = Extension(
        'zeroforcing.metagraph',
        sources=['zeroforcing/metagraph/*.pyx']
        )

setup(
        name='zeroforcing',
        packages=['zeroforcing.fastqueue', 'zeroforcing.metagraph'],
        cmdclass={'build_ext': build_ext},
        ext_modules=cythonize(
            [fastqueue, metagraph],
            compiler_directives={'language_level' : "3"}
            )
        )
