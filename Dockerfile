FROM python:3.14-slim-bookworm

ENV PYTHONDONTWRITEBYTECODE=1 PIP_DISABLE_PIP_VERSION_CHECK=1 PIP_NO_CACHE_DIR=1 ANSIBLE_LOCAL_TEMP=/tmp/ansible/local

RUN apt-get update && apt-get install --yes --no-install-recommends ca-certificates openssh-client && mkdir -p /tmp/ansible/local /tmp/ssh && rm -rf /var/lib/apt/lists/*

COPY requirements-controller.txt /tmp/requirements-controller.txt
COPY requirements.yml /tmp/requirements.yml
RUN python -m pip install --requirement /tmp/requirements-controller.txt && ansible-galaxy collection install --requirements-file /tmp/requirements.yml --collections-path /usr/share/ansible/collections && rm -f /tmp/requirements-controller.txt /tmp/requirements.yml

WORKDIR /workspace
CMD ["ansible", "--version"]
