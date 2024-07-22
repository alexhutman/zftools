FROM sagemath/sagemath:10.3

ARG ZF_BUILD_ARGS

COPY --chown=sage:sage . ./zeroforcing
WORKDIR ./zeroforcing

RUN : \
    #&& sage --python3 setup.py build \
    && sudo apt update && sudo apt install unzip \
    && sage -pip install -r test/requirements.txt \
    && sage --python3 setup.py sdist \
    && echo "HELLO FROM DOCKERFILE" \
    && tar -tf dist/zeroforcing* \
    && sage -pip install dist/zeroforcing*
    #&& sage -pip install .
    #&& sage --python3 setup.py sdist bdist_wheel

#ENTRYPOINT sage -pip install dist/zeroforcing*
#ENTRYPOINT sage --python3 -m pytest -x --profile
ENTRYPOINT /bin/bash
