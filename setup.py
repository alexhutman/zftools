import argparse
import glob
import itertools
import os
import shutil
import sys
import textwrap

from distutils.command.clean import clean
from distutils.core import setup
from distutils.extension import Extension
from pathlib import Path

from Cython.Build import cythonize
from Cython.Distutils import build_ext


_BUILD_EXT_CMD = "build_ext"
_CLEAN_CMD = "clean"
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
        # TODO: Gather the list first, then ask if user wants to delete, add a -y flag ('store_true') to auto say yes, only THEN delete
        all_ext_src_paths = (Path(source) for ext in _extension_modules for source in ext.sources) # TODO: get these recursively in case Extensions are nested (if even possible?)
        artifact_exts = [".c", ".*.so"]
        all_artifact_paths = CleanZeroForcing.__get_artifact_globs_gen(all_ext_src_paths, artifact_exts)

        pycache_dir_name = "__pycache__"
        all_pycache_path_globs = {Path("**") / pycache_dir_name}

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
                _BUILD_EXT_CMD: InstallZeroForcing,
                _CLEAN_CMD: CleanZeroForcing
                },
            }

    if zf_args.subcommand == _BUILD_EXT_CMD:
        comp_directives = {
            "language_level": zf_args.compiler_lang
        }

        if zf_args.debug:
            print(f"Compiling in debug mode")
            comp_directives.update({
                    "profile": True,
                    "linetrace": True
                })
            for ext in extensions:
                ext.define_macros = [("CYTHON_TRACE", 1)]

        # Only Cythonize if we're calling build_ext
        setup_params.update({
            "ext_modules": cythonize(
                extensions,
                compiler_directives=comp_directives
            )
        })
    return setup_params

def add_zero_forcing_parser(subparser):
    def inner(*args, **kwargs):
        updated_kwargs = {
            **kwargs,
            "formatter_class": ZeroForcingFormatter
            }
        return subparser.add_parser(*args, **updated_kwargs)
    return inner

def _get_cmd_args():
    # TODO: Probably not make current directory the default sage root
    sage_root = os.getenv("SAGE_ROOT")
    if sage_root:
        sage_root = Path(sage_root).resolve() / "sage"

    setup_file_path = Path(__file__).name
    parser = argparse.ArgumentParser(
            prog=f"{sage_root if sage_root is not None else '[path_to_sage_executable]'} {setup_file_path}",
            formatter_class=ZeroForcingFormatter
            )
    subparser = parser.add_subparsers(title="subcommands",
                                      help='valid subcommands',
                                      dest="subcommand",
                                      required=True)
    zf_subparser_add = add_zero_forcing_parser(subparser)

    build_ext_subparser = zf_subparser_add(
            _BUILD_EXT_CMD,
            help='build the Zero Forcing code',
            )
    clean_subparser = zf_subparser_add(
            _CLEAN_CMD,
            help='clean your workspace of all build artifacts',
            )
    build_ext_subparser.add_argument(
            '--debug',
            action='store_true',
            help="whether or not to compile in debug mode, which allows for profiling and line tracing."
            )

    build_ext_subparser.add_argument(
            "--compiler-lang",
            default="2",
            choices=["2", "3"],
            help=textwrap.dedent(
                """\
                the version to use for the Cython compiler's \"language_level\" directive. (default: %(default)s)
                - https://cython.readthedocs.io/en/latest/src/userguide/source_files_and_compilation.html#compiler-directives
                """)
            )

    return parser.parse_known_args()

class ZeroForcingFormatter(
        argparse.ArgumentDefaultsHelpFormatter,
        argparse.RawTextHelpFormatter):
    def _get_help_string(self, action): # Adapted from https://stackoverflow.com/a/34558278
        help_str = action.help
        defaulting_nargs = [argparse.OPTIONAL, argparse.ZERO_OR_MORE]

        default_str_present = '%(default)' in action.help
        is_suppress_action = action.default is argparse.SUPPRESS
        not_sure_about_this_one = action.option_strings or action.nargs in defaulting_nargs
        conditions = [
                not default_str_present,
                not is_suppress_action,
                not_sure_about_this_one
                ]
        if all(conditions):
            help_str += ' (default: %(default)s)'
        return help_str

def main():
    zero_forcing_args, setup_args = _get_cmd_args()
    setup(**_get_setup_parameters(_extension_modules, zero_forcing_args, setup_args))

if __name__ == "__main__":
    main()
