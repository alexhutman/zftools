import argparse
import glob
import io
import itertools
import os
import re
import shutil
import sys
import textwrap

from contextlib import redirect_stdout, redirect_stderr
from distutils.command.clean import clean
from distutils.core import setup
from distutils.extension import Extension
from functools import reduce
from pathlib import Path


from Cython.Build import cythonize
from Cython.Compiler.Errors import CompileError
from Cython.Distutils import build_ext


_extension_modules = [
        Extension(
            'zeroforcing.fastqueue',
            sources=['zeroforcing/fastqueue.pyx']
        ),
        Extension(
            'zeroforcing.metagraph',
            sources=['zeroforcing/metagraph.pyx']
        )
]

class CleanZeroForcing(clean):
    # Normal clean + forces the "--all" flag + cleans build extensions
    def initialize_options(self, *args, **kwargs):
        super().initialize_options(*args, **kwargs)
        self.all = True

    def run(self):
        self.__clean_artifacts()
        super().run()

    @staticmethod
    def __delete_file(file_path_to_remove, notify_before_deleting=False):
        if notify_before_deleting:
            CleanZeroForcing.__notify_path_removal(file_path_to_remove)

        try:
            os.remove(file_path_to_remove)
        except FileNotFoundError as exc:
            # File does not exist is fine -- as long as it ain't here
            pass

    @staticmethod
    def __delete_dir(dir_path_to_remove, notify_before_deleting=False):
        if notify_before_deleting:
            CleanZeroForcing.__notify_path_removal(dir_path_to_remove)

        try:
            shutil.rmtree(dir_path_to_remove)
        except OSError as err:
            # Skip File(Dir)NotFound
            if err.errno in [2]:
                # Dir does not exist is fine -- as long as it ain't here
                return
            # Skip PermissionError
            if err.errno in [13]:
                print(f"permission denied trying to delete {dir_path_to_remove}. skipping...", file=sys.stderr)
                return
            # Otherwise, re-raise
            __notify_path_removal_err(dir_path_to_remove)
            raise err

    @staticmethod
    def __delete_file_or_dir(path_to_remove, print_globs_only=True):
        resolved_glob_paths_gen = glob.iglob(str(path_to_remove), recursive=True)
        # Test to see if glob is empty or not, we only need to check the 1st value
        try:
            first_path = next(resolved_glob_paths_gen)

            # Prints globs to avoid cluttering output with each individual file
            if print_globs_only:
                CleanZeroForcing.__notify_path_removal(path_to_remove)
        except StopIteration:
            return
        # Restore first_path since we grabbed it earlier
        resolved_glob_paths_gen = itertools.chain([first_path], resolved_glob_paths_gen)

        for artifact_path in map(Path, resolved_glob_paths_gen):
            should_notify = not print_globs_only
            if artifact_path.is_file():
                CleanZeroForcing.__delete_file(artifact_path, notify_before_deleting=should_notify)
            elif artifact_path.is_dir():
                CleanZeroForcing.__delete_dir(artifact_path, notify_before_deleting=should_notify)

    @staticmethod
    def __remove_all_suffixes(path):
        cur_path = path
        while len(cur_path.suffixes) > 0:
            cur_path = cur_path.with_suffix('')
        return cur_path

    @staticmethod
    def __get_artifact_globs_gen(artifact_paths, file_exts):
        for artifact_path in artifact_paths:
            base_path = CleanZeroForcing.__remove_all_suffixes(artifact_path)
            for file_ext in file_exts:
                yield base_path.with_suffix(file_ext)

    @staticmethod
    def __clean_artifacts():
        # We're removing files from the filesystem, so it's better to be careful :)
        all_ext_src_paths = (Path(source) for ext in _extension_modules for source in ext.sources) # TODO: get these recursively in case Extensions are nested (if even possible?)
        artifact_exts = [".c", ".*.so"]
        subdirs = ["", "**"] # Current directory and all subdirectories

        all_pycache_path_globs = {(Path(ext.name.split('.')[0]) / Path(subdir) / "__pycache__") for ext in _extension_modules for subdir in subdirs}
        all_artifact_paths = CleanZeroForcing.__get_artifact_globs_gen(all_ext_src_paths, artifact_exts)

        all_paths_to_remove = itertools.chain(all_pycache_path_globs, all_artifact_paths)
        for path_to_remove in map(Path, all_paths_to_remove):
            CleanZeroForcing.__delete_file_or_dir(path_to_remove)

    @staticmethod
    def __notify_path_removal(path):
        print(f"removing '{path}'", file=sys.stderr)

    @staticmethod
    def __notify_path_removal_err(path):
        print(f"could not remove '{path}'", file=sys.stderr)


class InstallZeroForcing(build_ext):
    # Normal build_ext + forces the "--inplace" flag
    def initialize_options(self, *args, **kwargs):
        super().initialize_options(*args, **kwargs)
        self.inplace = True


def _get_setup_parameters(extensions, zf_args, setup_args):
    setup_params = {
            "name": "zeroforcing",
            "packages": [ext.name for ext in extensions],
            "cmdclass": {
                "build_ext": InstallZeroForcing,
                "clean": CleanZeroForcing
                },
            }

    if "build_ext" in setup_args: # Only Cythonize if we're calling build_ext
        setup_params.update({
            "ext_modules": cythonize(
                extensions,
                compiler_directives={
                    "language_level": zf_args.compiler_lang
                }
            )
        })
    return setup_params

def _get_cmd_args():
    sage_root = Path(os.getenv("SAGE_ROOT", default=".")).resolve()
    setup_file_path = Path(__file__).name
    parser = argparse.ArgumentParser(
            prog=f"{sage_root if sage_root.exists() else '[path_to_sage_executable]'} {setup_file_path}",
            formatter_class=argparse.ArgumentDefaultsHelpFormatter
            )

    parser.add_argument(
            "--compiler-lang",
            default="2",
            choices=["2", "3"],
            help="The version to use for the Cython compiler's \"language_level\" directive.")

    return parser.parse_known_args()

def _run_setup(zf_args, setup_args):
    compile_err = None

    with redirect_stderr(io.StringIO()) as new_stderr:
        try:
            setup(**_get_setup_parameters(_extension_modules, zf_args, setup_args))
        except CompileError as err:
            # CompileError doesn't actually contain the error that setup prints to stdout,
            # so have to do the below stderr filter mess :D
            compile_err = err

    # Can't seem to loop through output line by line as it prints -- doing it after
    stderr_output = new_stderr.getvalue()
    print(stderr_output, file=sys.stderr) # Re-print stderr since we intercepted it
    _detect_bitset_err(stderr_output, zf_args.compiler_lang)

    if compile_err is not None:
        raise compile_err

def _detect_bitset_err(stderr_output, compiler_lang):
    bitset_err_regex = re.compile(r"bitset_base\.pxd.*Cannot assign type")
    using_python_three_directive = (compiler_lang == '3')
    if using_python_three_directive and bool(bitset_err_regex.search(stderr_output)):
        addendum = textwrap.dedent("""
            This is because that Sage bitset module uses / for integer division in accordance with Python2, which represents float division in Python3.
            The divisions will hopefully be fixed to use // in a future version of Sage.
            Not sure how much of a benefit (if at all) the compiler directive provides but I'm including it in case :)""")
        print(addendum, file=sys.stderr)

def main():
    zero_forcing_args, setup_args = _get_cmd_args()
    _run_setup(zero_forcing_args, setup_args)

if __name__ == "__main__":
    main()
