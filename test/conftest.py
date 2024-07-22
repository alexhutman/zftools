import argparse
import cProfile
import io
import os
import pstats
import pytest

_DEFAULT_NUM_RESULTS = 25
_NUM_RESULTS_FLAG = "--num-results"
_SHOULD_PROFILE_FLAG = "--profile"

_PROFILER_ENABLED_TAG = "profiler_enabled"
_PROFILER_RESULTS_SECTION = "profiler results:"


def check_positive(value):
    pos_int_err = argparse.ArgumentTypeError("Provide a positive integer.")
    try:
        ivalue = int(value)
        if ivalue > 0:
            return ivalue
    except ValueError as val_err:
        raise pos_int_err from val_err

    raise pos_int_err


def help_str_with_default(help_str, default):
    return f"{help_str} (default: {default})"


def pytest_addoption(parser):
    profile_group = parser.getgroup("Zero forcing options")
    profile_group.addoption(
        _SHOULD_PROFILE_FLAG,
        action="store_true",
        help=help_str_with_default(
            "Whether to profile the tests or not. Not too helpful unless you compile in debug mode.", False
        ),
    )
    # Pytest uses their own version of options, don't think they support subparsers
    profile_group.addoption(
        _NUM_RESULTS_FLAG,
        type=check_positive,
        help=help_str_with_default("Number of profiler results to return.", _DEFAULT_NUM_RESULTS),
        default=_DEFAULT_NUM_RESULTS,
    )


def pytest_sessionstart(session):
    session.results = {}


def pytest_sessionfinish(session, exitstatus):
    passed_amount = sum(1 for result in session.results.values() if result.passed)
    failed_amount = sum(1 for result in session.results.values() if result.failed)


@pytest.hookimpl(tryfirst=True, hookwrapper=True)
def pytest_runtest_makereport(item, call):  # https://stackoverflow.com/a/51714659
    outcome = yield
    result = outcome.get_result()

    if result.when == "call":
        item.session.results[item] = result

    # On teardown of last item
    if result.when == "teardown" and item.should_display_profile_results:
        profiler_results = item.session.profiler_finalizer()
        section = (_PROFILER_RESULTS_SECTION, profiler_results)
        result.sections.append(section)


def pytest_report_header(config, start_path):
    should_profile = config.getoption(_SHOULD_PROFILE_FLAG)
    print(f"{_PROFILER_ENABLED_TAG}:", should_profile)


def pytest_collection_modifyitems(session, config, items):
    should_profile = config.getoption(_SHOULD_PROFILE_FLAG)
    for item in items:
        item.should_display_profile_results = False

    if should_profile and len(items) > 0:
        # Display profile results after last item
        # Arguably should do this in the sessionfinish hook but..
        items[-1].should_display_profile_results = True


def pytest_terminal_summary(terminalreporter, exitstatus, config):
    reports = terminalreporter.getreports("")
    content = os.linesep.join(text for report in reports for secname, text in report.sections)
    if content:
        terminalreporter.ensure_newline()
        terminalreporter.section(_PROFILER_RESULTS_SECTION, blue=True, bold=True)
        terminalreporter.write_line(content + os.linesep)


@pytest.fixture(scope="session")
def profiler(request):
    # Setup
    should_profile = request.config.getoption(_SHOULD_PROFILE_FLAG)
    if should_profile:
        num_results = request.config.getoption(_NUM_RESULTS_FLAG)
        prof = cProfile.Profile()
        yield prof

        # Teardown
        def profiler_teardown():
            results = io.StringIO()
            # TODO: Get sortby from CLI?
            sortby = pstats.SortKey.CUMULATIVE
            stats = pstats.Stats(prof, stream=results).sort_stats(sortby)
            stats.print_stats(num_results)
            return results.getvalue().rstrip()

        request.session.profiler_finalizer = profiler_teardown
    else:
        yield None
