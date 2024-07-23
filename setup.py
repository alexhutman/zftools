from os.path import join as opj

from setuptools import setup, Extension, find_packages
from setuptools.command.bdist_egg import bdist_egg as _bdist_egg

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


def get_setup_parameters(extensions):
    setup_params = {
        "name": "zeroforcing",
        "author": "Alexander Hutman, Louis Deaett",
        "license": "GPLv3",
        "license_files": ["LICENSE"],
        "version": "0.1.0",
        "url": "https://github.com/alexhutman/ZeroForcingNumber",
        "description": "Find the zero forcing set of graphs.",
        "packages": find_packages(where='src'),
        "package_data": {"zeroforcing": ["*.pxd"]},
        "package_dir": {"": "src"},
        "ext_modules": extensions,
        "install_requires": ["setuptools>=60.0", "sagemath-standard", "Cython"],
        "extras_require": { "test": ['pytest'] }
    }

    cmdclass = {"bdist_egg": no_egg, "build_ext": zf_cythonize}
    if SAGE_INSTALLED:
        cmdclass.update({"build_cython": sage_build_cython, "wavefront": build_wavefront})

    setup_params.update({"cmdclass": cmdclass})
    return setup_params


def main():
    extensions = [
        Extension("zeroforcing.fastqueue", sources=["src/zeroforcing/fastqueue.pyx"]),
        Extension("zeroforcing.metagraph", sources=["src/zeroforcing/metagraph.pyx"]),
    ]

    setup(**get_setup_parameters(extensions))

if __name__ == "__main__":
    main()
