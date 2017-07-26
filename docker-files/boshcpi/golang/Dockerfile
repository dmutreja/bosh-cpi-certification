FROM boshcpi/tools-base:latest

ARG GOLANG_VERSION=1.8.3
ARG GOLANG_SHA256SUM=1862f4c3d3907e59b04a757cfda0ea7aa9ef39274af99a784f5be843c80c6772

RUN mkdir -p /opt/go
ENV GOPATH /opt/go
ENV PATH /usr/local/go/bin:/opt/go/bin:$PATH

RUN cd /tmp && \
    wget -nv https://storage.googleapis.com/golang/go$GOLANG_VERSION.linux-amd64.tar.gz && \
    ( \
        echo "$GOLANG_SHA256SUM go$GOLANG_VERSION.linux-amd64.tar.gz" | \
        sha256sum -c - \
    ) && \
    tar -C /usr/local -xzf go$GOLANG_VERSION.linux-amd64.tar.gz && \
    rm go$GOLANG_VERSION.linux-amd64.tar.gz

RUN go get github.com/golang/lint/golint && \
    go get github.com/onsi/ginkgo/ginkgo
