FROM sagemath/sagemath:10.3

RUN sage -pip install --no-cache-dir build

COPY --chown=sage:sage . ./zftools

RUN sage --python3 -m build --no-isolation zftools/
RUN sage -pip install --no-cache-dir zftools/dist/*.tar.gz
