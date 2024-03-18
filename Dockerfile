FROM sagemath/sagemath:10.1

ARG ZF_BUILD_ARGS

COPY --chown=sage:sage . ./zeroforcing
WORKDIR ./zeroforcing

RUN : \
	&& sage --python3 setup.py build_ext ${ZF_BUILD_ARGS} \
	&& sage --python3 -m pip install -r test/requirements.txt

ENTRYPOINT ["/bin/bash"]
