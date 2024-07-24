from os.path import join as opj

from setuptools import setup, Extension, find_packages
from setuptools.command.bdist_egg import bdist_egg as _bdist_egg

classifiers = [
    "Development Status :: 4 - Beta",
    "Environment :: Other Environment",
    "Intended Audience :: Education",
    "Intended Audience :: Science/Research",
    "License :: OSI Approved :: GNU General Public License v3 (GPLv3)",
    "Programming Language :: Cython",
    "Programming Language :: Python :: 3 :: Only",                 # Could experiment testing Python2 and exact versions but... why?
    "Programming Language :: Python :: Implementation :: CPython", # Surely C extensions only work on CPython..?
    "Topic :: Scientific/Engineering :: Mathematics",
    "Topic :: Software Development :: Libraries :: Python Modules",
]

try:
    from sage_setup.command.sage_build_cython import sage_build_cython
    from sage_setup.command.sage_build_ext import sage_build_ext as _build_ext

    SAGE_INSTALLED = True
except ImportError:
    from setuptools.command.build_ext import build_ext as _build_ext
    SAGE_INSTALLED = False

class no_egg(_bdist_egg):
    def run(self):
        from distutils.errors import DistutilsOptionError
        raise DistutilsOptionError("Honestly just copying https://github.com/sagemath/cysignals/blob/c901dc9217de735c67ca5daf3dff6276813a05b5/setup.py#L186-L193")

class zf_cythonize(_build_ext):
    base_directives = dict(
         binding=False,
         language_level=3,
    )
    def run(self):
        dist = self.distribution
        ext_modules = dist.ext_modules
        if ext_modules:
            dist.ext_modules[:] = self.cythonize(ext_modules)
        super().run()

    def cythonize(self, extensions):
        # Run Cython with -Werror on continuous integration services
        # with Python 3.6 or later
        from Cython.Compiler import Options
        Options.warning_errors = False

        compiler_directives = dict(**self.base_directives)
        from Cython.Build.Dependencies import cythonize
        return cythonize(extensions,
                         compiler_directives=compiler_directives)

class build_wavefront(zf_cythonize):
    def initialize_options(self):
        super().initialize_options()
        ext_name = "zeroforcing.test.verifiability.wavefront"
        self.distribution.packages = [ext_name]
        self.distribution.ext_modules = [Extension(ext_name, sources=[opj("test", "verifiability", "wavefront.pyx")])]

with open("VERSION") as f:
    VERSION = f.read().strip()


def get_setup_parameters(extensions):
    setup_params = dict(
        name="zeroforcing",
        author="Alexander Hutman, Louis Deaett",
        license="GNU General Public License, version 3",
        version=VERSION,
        url="https://github.com/alexhutman/ZeroForcingNumber",
        description="Find the zero forcing set of graphs",
        classifiers=classifiers,
        packages=find_packages(where='src'),
        package_data={"zeroforcing": ["*.pxd"]},
        package_dir={"": "src"},
        ext_modules=extensions,
        install_requires=["setuptools>=60.0", "sagemath-standard", "Cython"],
        extras_require={ "test": ['pytest'] },
    )

    cmdclass = dict(
        bdist_egg=no_egg,
        build_ext=zf_cythonize
    )
    if SAGE_INSTALLED:
        cmdclass.update(dict(
            build_cython=sage_build_cython,
            wavefront=build_wavefront
        ))

    setup_params.update(dict(
        cmdclass=cmdclass
    ))
    return setup_params


def main():
    extensions = [
        Extension("zeroforcing.fastqueue", sources=[opj("src", "zeroforcing", "fastqueue.pyx")]),
        Extension("zeroforcing.metagraph", sources=[opj("src", "zeroforcing", "metagraph.pyx")]),
    ]

    setup(**get_setup_parameters(extensions))

if __name__ == "__main__":
    main()
