FROM gcr.io/google.com/cloudsdktool/cloud-sdk:slim

ARG HELM_VERSION=v3.16.2

COPY requirements.txt /tmp/requirements.txt

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl python3-pip \
    && pip3 install --no-cache-dir --break-system-packages -r /tmp/requirements.txt \
    && curl -fsSLo /tmp/helm.tar.gz "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz" \
    && tar -xzf /tmp/helm.tar.gz -C /tmp \
    && install /tmp/linux-amd64/helm /usr/local/bin/helm \
    && rm -rf /var/lib/apt/lists/* /tmp/helm.tar.gz /tmp/linux-amd64 /tmp/requirements.txt
