FROM sagemath/sagemath

ENV BRANCH=cleanup
ARG ZF_BUILD_ARGS

RUN : \
	&& sudo apt-get -y update \
	&& sudo apt-get -y install git \
	&& git clone --depth 1 --branch ${BRANCH} https://github.com/alexhutman/ZeroForcingNumber.git

WORKDIR ./ZeroForcingNumber

RUN : \
	&& sage --python3 setup.py build_ext ${ZF_BUILD_ARGS} \
	&& sage --python3 -m pip install -r test/requirements.txt

ENTRYPOINT ["/bin/bash"]
