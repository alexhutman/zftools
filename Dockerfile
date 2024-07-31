FROM sagemath/sagemath:10.3

RUN sage -pip install build

COPY --chown=sage:sage . ./zeroforcing

#RUN sage --python3 -m build --verbose --no-isolation zeroforcing/
#RUN sage -pip install --editable zeroforcing/
RUN COMPILE_WAVEFRONT=true sage --python3 -m build --verbose --no-isolation zeroforcing/
#RUN sage -pip install --editable zeroforcing
RUN sage -pip install zeroforcing/dist/*.whl
RUN ls /home/sage/sage/local/var/lib/sage/venv-python3.11.1/lib/python3.11/site-packages/zeroforcing
