FROM sagemath/sagemath:10.3

COPY --chown=sage:sage . ./zeroforcing

RUN sage -pip install zeroforcing/
