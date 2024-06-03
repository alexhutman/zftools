FROM sagemath/sagemath:10.3

ARG ZF_BUILD_ARGS

COPY --chown=sage:sage . ./zeroforcing
WORKDIR ./zeroforcing

#RUN apt update -y && apt install -y vim tree

RUN : \
    && sage --python3 setup.py build_ext ${ZF_BUILD_ARGS} \
    && sage --python3 -m pip install -r test/requirements.txt
    #&& sage --python3 -m pip install -r test/requirements.txt || true

ENTRYPOINT /usr/bin/env bash
#ENTRYPOINT sage --python3 -m pytest -x --profile
