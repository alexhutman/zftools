from setuptools.command.bdist_egg import bdist_egg as _bdist_egg
from setuptools.command.build import build
from setuptools import Extension

from os.path import join as opj

try:
    from sage_setup.command.sage_build_ext import sage_build_ext as _build_ext
except ImportError:
    from setuptools.command.build_ext import build_ext as _build_ext


class no_egg(_bdist_egg):
    def run(self):
        from distutils.errors import DistutilsOptionError
        raise DistutilsOptionError("Honestly just copying https://github.com/sagemath/cysignals/blob/c901dc9217de735c67ca5daf3dff6276813a05b5/setup.py#L186-L193")

class zf_cythonize(_build_ext):
    base_directives = dict(
         binding=False,
         language_level=3,
    )
    def initialize_options(self):
        dist = self.distribution
        ext_modules = dist.ext_modules
        dist.packages = ["zftools"]
        if ext_modules:
            dist.ext_modules[:] = self.cythonize(ext_modules)
        super().initialize_options()

    def cythonize(self, extensions):
        # Run Cython with -Werror on continuous integration services
        # with Python 3.6 or later
        from Cython.Compiler import Options
        Options.warning_errors = False

        compiler_directives = dict(**self.base_directives)
        from Cython.Build.Dependencies import cythonize
        return cythonize(extensions,
                         compiler_directives=compiler_directives)

class build_zf_code(zf_cythonize):
    def initialize_options(self):
        self.distribution.ext_modules = [
            Extension("zftools.fastqueue", sources=[opj("src", "zftools", "fastqueue.pyx")]),
            Extension("zftools.metagraph", sources=[opj("src", "zftools", "metagraph.pyx")]),
        ]
        super().initialize_options()

class build_wavefront(zf_cythonize):
    def initialize_options(self):
        ext_name = "zftools.test.verifiability.wavefront"
        self.distribution.ext_modules = [Extension(ext_name, sources=[opj("test", "verifiability", "wavefront.pyx")])]
        super().initialize_options()

class ZFBuild(build):
    @classmethod
    def get_additional_subcommands(cls, build_wavefront):
        addtl_subcommands = [('zftools', None)]
        if build_wavefront:
            addtl_subcommands.append(('wavefront', None))

        cls.sub_commands = addtl_subcommands

def InitZFBuild(build_wavefront=False):
    ZFBuild.get_additional_subcommands(build_wavefront)
    return ZFBuild
