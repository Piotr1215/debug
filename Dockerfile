FROM rust:1.63 AS rustbase

FROM curlimages/curl:7.85.0 AS curlbase
WORKDIR /home/curl_user

FROM rustbase AS bandwhich
# renovate: datasource=crate depName=bandwhich
ARG BANDWHICH_VERSION=0.20.0
RUN set -x && \
    cargo install bandwhich --version "${BANDWHICH_VERSION}" && \
    /usr/local/cargo/bin/bandwhich --version

FROM curlbase AS gping
# renovate: datasource=github-releases depName=orf/gping
ARG GPING_VERSION=gping-v1.3.1
RUN set -x && \
    curl -sL https://github.com/orf/gping/releases/download/${GPING_VERSION}/gping-$(uname -m)-unknown-linux-musl.tar.gz | tar xz gping && \
    ./gping --version

FROM curlbase AS starship
# renovate: datasource=github-releases depName=starship/starship
ARG STARSHIP_VERSION=v1.10.3
RUN set -x && \
    curl -sL https://github.com/starship/starship/releases/download/${STARSHIP_VERSION}/starship-$(uname -m)-unknown-linux-musl.tar.gz | tar xz starship && \
    ./starship --version

FROM curlbase AS kubectl
ARG TARGETARCH
# renovate: datasource=github-releases depName=kubernetes/kubernetes
ARG KUBECTL_VERSION=v1.25.0
RUN set -x && \
    curl -sLO "https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl" && \
    chmod +x kubectl && \
    ./kubectl version --client

FROM curlbase AS etcdctl
ARG TARGETARCH
# renovate: datasource=github-releases depName=etcd-io/etcd
ARG ETCD_VERSION=v3.5.5
RUN set -x && \
    curl -sL "https://storage.googleapis.com/etcd/${ETCD_VERSION}/etcd-${ETCD_VERSION}-linux-${TARGETARCH}.tar.gz" | \
      tar xvzf - "etcd-${ETCD_VERSION}-linux-${TARGETARCH}/etcdctl" --strip-components=1 && \
    chmod +x etcdctl && \
    ./etcdctl version

FROM golang:1.19 AS hey
# renovate: datasource=github-releases depName=rakyll/hey
ARG HEY_VERSION=v0.1.4
ARG TARGETOS
ARG TARGETARCH
RUN set -x && \
    CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} go install "github.com/rakyll/hey@${HEY_VERSION}"

FROM ubuntu:22.04
LABEL org.opencontainers.image.source https://github.com/superbrothers/debug
ARG TARGETARCH
RUN set -x && \
    apt update && \
    DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends \
        bash \
        build-essential \
        ca-certificates \
        curl \
        dhcpdump \
        dnsutils \
        git \
        htop \
        iotop \
        iperf \
        iperf3 \
        iproute2 \
        iptables \
        iputils-ping \
        less \
        net-tools \
        netcat \
        nmap \
        nvtop \
        openssh-client \
        strace \
        sysbench \
        sysstat \
        tcpdump \
        traceroute \
        tree \
        vim \
        && \
    rm -rf /var/lib/apt/lists/*

SHELL ["/bin/bash", "-c"]

# renovate: datasource=github-releases depName=muesli/duf
ARG DUF_VERSION=v0.8.1
RUN set -x && \
    curl -L -o duf.deb "https://github.com/muesli/duf/releases/download/${DUF_VERSION}/duf_${DUF_VERSION/v/}_linux_${TARGETARCH}.deb" && \
    dpkg -i duf.deb && \
    rm duf.deb

# renovate: datasource=github-releases depName=sharkdp/bat
ARG BAT_VERSION=v0.22.1
RUN set -x && \
    curl -L -o bat.deb "https://github.com/sharkdp/bat/releases/download/${BAT_VERSION}/bat_${BAT_VERSION/v/}_${TARGETARCH}.deb" && \
    dpkg -i bat.deb && \
    rm bat.deb

COPY --from=hey /go/bin/hey /usr/local/bin/hey
COPY --from=bandwhich /usr/local/cargo/bin/bandwhich /usr/local/bin/bandwhich
COPY --from=gping /home/curl_user/gping /usr/local/bin/gping
COPY --from=starship /home/curl_user/starship /usr/local/bin/starship
COPY --from=kubectl /home/curl_user/kubectl /usr/local/bin/kubectl
COPY --from=etcdctl /home/curl_user/etcdctl /usr/local/bin/kubectl

# settings for starship
RUN set -x && \
    echo 'eval "$(starship init bash)"' >>/root/.bashrc
COPY config/starship/starship.toml /root/.config/starship.toml
