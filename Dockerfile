FROM sagemath/sagemath:10.3

ARG ZF_BUILD_ARGS

COPY --chown=sage:sage . ./zeroforcing
WORKDIR ./zeroforcing

RUN : \
    #&& sage --python3 setup.py build \
    && sage -pip install -r test/requirements.txt \
    && sage --python3 setup.py sdist \
    && echo "HELLO FROM DOCKERFILE" \
    && tar -tf dist/zfn* \
    && sage -pip install dist/zfn*
    #&& sage --python3 setup.py sdist bdist_wheel

#ENTRYPOINT sage --python3 -m pytest -x --profile
ENTRYPOINT /bin/bash
