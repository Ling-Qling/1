FROM mcr.microsoft.com/vscode/devcontainers/python:3.11

WORKDIR /workspace

COPY requirements.txt /tmp/pip-tmp/
RUN pip3 install --upgrade pip && \
    pip3 install --no-cache-dir -r /tmp/pip-tmp/requirements.txt

ENV PYTHONPATH=/workspace
