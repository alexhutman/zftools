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

class build_wavefront(_build_ext):
    def initialize_options(self):
        super().initialize_options()
        ext_name = "zeroforcing.test.verifiability.wavefront"
        self.distribution.packages = [ext_name]
        self.distribution.ext_modules = [Extension(ext_name, sources=["test/verifiability/wavefront.pyx"])]


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

    cmdclass = {"bdist_egg": no_egg, "build_ext": _build_ext}
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
