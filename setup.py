from setuptools import setup, find_packages, Extension
from setuptools.command.bdist_egg import bdist_egg as _bdist_egg

import sys
#from Cython.Build import cythonize
#from Cython.Build import build_ext


_extension_modules = [
    Extension("zeroforcing.fastqueue", sources=["zeroforcing/fastqueue.pyx"]),
    Extension("zeroforcing.metagraph", sources=["zeroforcing/metagraph.pyx"]),
    # TODO: Add flag whether or not to compile this
    #Extension("test.verifiability.wavefront", sources=["test/verifiability/wavefront.pyx"]),
]

#class build(build_orig):
    #def finalize_options(self):
        #super().finalize_options()
        #from Cython.Build import cythonize
        #print("HELLO FROM SETUP.PY")
        #self.distribution.ext_modules = cythonize(self.distribution.ext_modules,
                                                  #language_level=3)

class no_egg(_bdist_egg):
    def run(self):
        from distutils.errors import DistutilsOptionError
        raise DistutilsOptionError("https://github.com/sagemath/cysignals/blob/c901dc9217de735c67ca5daf3dff6276813a05b5/setup.py#L186-L193")

def _get_setup_parameters(extensions):
    is_building_bdist_wheel = "bdist_wheel" in sys.argv
    setup_params = {
        "name": "zeroforcing",
        "version": "0.1",
        #"package_data": {ext.name: ext.sources for ext in extensions},
        #"cmdclass": {"build_ext": InstallZeroForcing}
        "packages": ["zeroforcing"],
        "package_data": {"zeroforcing": ["*.pxd"]},
        "ext_modules": _extension_modules,
        #"cmdclass": {"build": build}
        "install_requires": ["setuptools>=60.0"]
    }

    # https://stackoverflow.com/a/41629156/6708303
    #pkgs = find_packages(exclude=('test*')).extend([ext.name for ext in extensions])
    #print(f"{pkgs=}")
    if is_building_bdist_wheel:
        from sage_setup.command.sage_build_cython import sage_build_cython
        from sage_setup.command.sage_build_ext import sage_build_ext as build_ext_orig
        #from setuptools.command.build_ext import build_ext as build_ext_orig
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

        setup_params.update({"cmdclass": {"build_cython": sage_build_cython, "build_ext": build_ext_orig, "bdist_egg": no_egg}})
    print(setup_params)
    #exit(1)
    return setup_params




def main():
    setup(**_get_setup_parameters(_extension_modules))


if __name__ == "__main__":
    main()
