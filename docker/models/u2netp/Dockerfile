FROM python:3.11.9-slim-bookworm

WORKDIR /workspace

COPY requirements.txt /tmp/requirements.txt

RUN pip install --no-cache-dir --index-url https://download.pytorch.org/whl/cpu torch==2.2.2+cpu \
    && pip install --no-cache-dir -r /tmp/requirements.txt

ENTRYPOINT ["python", "/workspace/script/models/convert_u2netp_to_onnx.py"]
