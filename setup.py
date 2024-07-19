from setuptools import setup, find_packages, Extension
from setuptools.command.build_ext import build_ext as build_ext_orig
from setuptools.command.build import build as build_orig

#from Cython.Build import cythonize
#from Cython.Build import build_ext


_extension_modules = [
    Extension("zeroforcing.fastqueue", sources=["zeroforcing/fastqueue.pyx"]),
    Extension("zeroforcing.metagraph", sources=["zeroforcing/metagraph.pyx"]),
    # TODO: Add flag whether or not to compile this
    Extension("test.verifiability.wavefront", sources=["test/verifiability/wavefront.pyx"]),
]

#class InstallZeroForcing(build_ext):
    # Normal build_ext + forces the "--inplace" flag
    #def initialize_options(self, *args, **kwargs):
        #super().initialize_options(*args, **kwargs)
        #self.inplace = True

# https://stackoverflow.com/a/26698408/6708303
class lazy_cythonize(list):
    def __init__(self, callback):
        self._list, self.callback = None, callback
    def c_list(self):
        if self._list is None: self._list = self.callback()
        return self._list
    def __iter__(self):
        for e in self.c_list(): yield e
    def __getitem__(self, ii): return self.c_list()[ii]
    def __len__(self): return len(self.c_list())

class build(build_orig):
    def finalize_options(self):
        super().finalize_options()
        from Cython.Build import cythonize
        print("HELLO FROM SETUP.PY")
        self.distribution.ext_modules = cythonize(self.distribution.ext_modules,
                                                  language_level=3)
#class build_ext(build_ext_orig):
    #def finalize_options(self):
        #super().finalize_options()
        #from Cython.Build import cythonize
        #print("HELLO FROM SETUP.PY")
        #self.distribution.ext_modules = cythonize(self.distribution.ext_modules,
                                                  #language_level=3)

def _get_setup_parameters(extensions):
    setup_params = {
        "name": "zeroforcing",
        #"packages": find_packages(exclude=('test*')),
        #"package_data": {ext.name: ext.sources for ext in extensions},
        #"cmdclass": {"build_ext": InstallZeroForcing}
        #"cmdclass": {"build_ext": build_ext}
        "cmdclass": {"build": build}
    }
    print(setup_params)
    #exit(1)
    return setup_params



    is_debug = False

    force_release_ext_names = {"test.verifiability.wavefront"}
    debug_exts = [ext for ext in extensions if is_debug and ext.name not in force_release_ext_names]
    release_exts = [ext for ext in extensions if ext.name not in {e.name for e in debug_exts}]
    comp_directives = {"language_level": '3', "binding": False}

    cythonized = []
    if debug_exts:
        for ext in debug_exts:
            ext.define_macros = [("CYTHON_TRACE", 1)]
        print(f"Compiling the following extensions in debug mode: {', '.join((ext.name for ext in debug_exts))}")
        cythonized.extend(cythonize(debug_exts, compiler_directives={**comp_directives, "linetrace": True}))

    if release_exts:
        print(f"Compiling the following extensions in release mode: {', '.join((ext.name for ext in release_exts))}")
        cythonized.extend(cythonize(release_exts, compiler_directives=comp_directives))

    setup_params.update({"ext_modules": cythonized})
    return setup_params

def main():
    setup(**_get_setup_parameters(_extension_modules))


if __name__ == "__main__":
    main()
