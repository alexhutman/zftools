from setuptools import setup, Extension
from setuptools.command.bdist_egg import bdist_egg as _bdist_egg


class no_egg(_bdist_egg):
    def run(self):
        from distutils.errors import DistutilsOptionError
        raise DistutilsOptionError("Honestly just copying https://github.com/sagemath/cysignals/blob/c901dc9217de735c67ca5daf3dff6276813a05b5/setup.py#L186-L193")


def get_setup_parameters(extensions):
    setup_params = {
        "name": "zeroforcing",
        "author": "Alexander Hutman, Louis Deaett",
        "license": "GPLv3",
        "license_files": ["LICENSE"],
        "version": "0.1.0",
        "url": "https://github.com/alexhutman/ZeroForcingNumber",
        "description": "Find the zero forcing set of graphs.",
        "packages": ["zeroforcing"],
        "package_data": {"zeroforcing": ["*.pxd"]},
        "package_dir": {"": "src"},
        "ext_modules": extensions,
        "install_requires": ["setuptools>=60.0", "sagemath-standard", "Cython"],
        "extras_require": { "dev": ['pytest'] }
    }

    cmdclass = {"bdist_egg": no_egg}
    try:
        from sage_setup.command.sage_build_cython import sage_build_cython
        from sage_setup.command.sage_build_ext import sage_build_ext as build_ext_orig

        cmdclass.update({"build_ext": build_ext_orig, "build_cython": sage_build_cython})
    except ImportError:
        pass

    setup_params.update({"cmdclass": cmdclass})
    return setup_params


def main():
    extensions = [
        Extension("zeroforcing.fastqueue", sources=["src/zeroforcing/fastqueue.pyx"]),
        Extension("zeroforcing.metagraph", sources=["src/zeroforcing/metagraph.pyx"]),
        # TODO: Add flag whether or not to compile this
        Extension("zeroforcing.test.verifiability.wavefront", sources=["test/verifiability/wavefront.pyx"]),
    ]

    setup(**get_setup_parameters(extensions))

if __name__ == "__main__":
    main()
