FROM public.ecr.aws/d3j8x8q7/olympus-base:latest

WORKDIR /app

COPY . .

RUN pip install --no-cache-dir --upgrade \
        -r requirements.txt \
        -r requirements-asyncio.txt \
        -r test-requirements.txt \
        -r test-requirements-asyncio.txt && \
    pip install --no-cache-dir --no-build-isolation -e .

CMD ["/bin/bash"]

