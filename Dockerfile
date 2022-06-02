FROM ubuntu:20.04

ENV HELM_VERSION 3.9.0
ENV KUBECTL_VERSION 1.24.1
ENV THUB_VERSION 0.5.9
ENV YQ_VERSION 4.25.2

COPY bin/cicd-*.sh /root/
COPY bin/step-*.sh /root/

RUN apt-get -y update \
    && apt-get -y upgrade \
    # && apt-get -y groupinstall "Development Tools" \
    && apt-get -y install build-essential \
    && apt-get -y install bzip2 curl git jq make tar zip unzip wget libdigest-sha-perl \
    && apt-get -y install libpng-dev libssl-dev python3 python3-pip python3-dev \
    && curl -fsSL https://deb.nodesource.com/setup_16.x | /bin/bash \
    && apt-get -y install nodejs \
    && pip3 install awscli boto3 \
    && npm install -g yarn npm webpack aws-sdk strip-ansi \
    && npm install -g terrahub@${THUB_VERSION} \
    && curl -fsSLO https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_amd64.tar.gz \
    && tar -xvzf yq_linux_amd64.tar.gz \
    && mv -f yq_linux_amd64 /usr/local/bin/yq \
    && curl -fsSLO https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz \
    && tar -xvzf helm-v${HELM_VERSION}-linux-amd64.tar.gz \
    && mv -f linux-amd64/helm /usr/local/bin/ \
    && rm -rf linux-amd64 \
    && curl -fsSLO https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl \
    && chmod 0755 kubectl \
    && mv -f kubectl /usr/local/bin/

RUN aws --version
RUN git --version
RUN jq --version
RUN yq --version
RUN helm version
RUN kubectl version --client
RUN terrahub --version

RUN mkdir -p /root/.kube && touch /root/.kube/config && chmod 0600 /root/.kube/config
RUN helm repo add confluentinc https://packages.confluent.io/helm && helm repo update
