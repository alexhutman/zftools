from setuptools import setup, Extension
from setuptools.command.bdist_egg import bdist_egg as _bdist_egg


class no_egg(_bdist_egg):
    def run(self):
        from distutils.errors import DistutilsOptionError
        raise DistutilsOptionError("Honestly just copying https://github.com/sagemath/cysignals/blob/c901dc9217de735c67ca5daf3dff6276813a05b5/setup.py#L186-L193")

"""
class build_ext(build_ext_orig):
    #def initialize_options(self, *args, **kwargs):
        #super().initialize_options(*args, **kwargs)
        #self.inplace = True

    def cythonize_extensions(self, debug=False):
        from Cython.Build.Dependencies import cythonize
        #from Cython.Build import cythonize

        force_release_ext_names = {"test.verifiability.wavefront"}
        debug_exts = [ext for ext in self.distribution.ext_modules if debug and ext.name not in force_release_ext_names]
        release_exts = [ext for ext in self.distribution.ext_modules if ext.name not in {e.name for e in debug_exts}]
        comp_directives = {"language_level": '3', "binding": False}

        cythonized = []
        if debug_exts:
            for ext in debug_exts:
                ext.define_macros = [("CYTHON_TRACE", 1)]
            print(f"Compiling the following extensions in debug mode: {', '.join((ext.name for ext in debug_exts))}")
            cythonized.extend(cythonize(debug_exts, build_dir="build", compiler_directives={**comp_directives, "linetrace": True}))

        if release_exts:
            print(f"Compiling the following extensions in release mode: {', '.join((ext.name for ext in release_exts))}")
            cythonized.extend(cythonize(release_exts, build_dir="build", compiler_directives=comp_directives))

        self.distribution.ext_modules = cythonized

    def run(self):
        print("HELLO FROM SETUP.PY")

        print(f"Before Cythonizing {self.distribution.ext_modules=}")
        self.cythonize_extensions()
        print(f"After Cythonizing {self.distribution.ext_modules=}")
        super().run()
"""


def get_setup_parameters(extensions):
    setup_params = {
        "name": "zeroforcing",
        "version": "0.1",
        "packages": ["zeroforcing"],
        "package_data": {"zeroforcing": ["*.pxd"]},
        "ext_modules": extensions,
        "install_requires": ["setuptools>=60.0"],
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
        Extension("zeroforcing.fastqueue", sources=["zeroforcing/fastqueue.pyx"]),
        Extension("zeroforcing.metagraph", sources=["zeroforcing/metagraph.pyx"]),
        # TODO: Add flag whether or not to compile this
        Extension("zeroforcing.test.verifiability.wavefront", sources=["test/verifiability/wavefront.pyx"]),
    ]

    setup(**get_setup_parameters(extensions))

if __name__ == "__main__":
    main()
