FROM python:3.11.9-slim-bookworm

WORKDIR /workspace

COPY requirements.txt /tmp/requirements.txt

RUN pip install --no-cache-dir -r /tmp/requirements.txt

ENTRYPOINT ["python", "/workspace/script/models/generate_u2netp_preprocessing_reference.py"]
