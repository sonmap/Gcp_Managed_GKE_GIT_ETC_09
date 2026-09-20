ARG BASE_IMAGE=asia-northeast3-docker.pkg.dev/prj-b-cicd-local-236d/ar-sandbox-platform/jupyterhub-k8s-singleuser-sample:4.2.0
FROM ${BASE_IMAGE}

ARG IMAGE_VERSION=4.2.0-r1-test

USER root

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      git \
      gnupg \
      jq \
      unzip && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /usr/share/keyrings && \
    curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg \
      | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
      > /etc/apt/sources.list.d/google-cloud-sdk.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends google-cloud-cli && \
    rm -rf /var/lib/apt/lists/*

RUN python -m pip install --no-cache-dir \
      pandas \
      pyarrow \
      db-dtypes \
      google-cloud-bigquery \
      google-cloud-storage

RUN printf '%s\n' "sandbox-jupyter-standard ${IMAGE_VERSION}" > /etc/sandbox-image-version

USER jovyan
WORKDIR /home/jovyan
