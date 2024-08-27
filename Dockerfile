#--- dockerfile with hugot dependencies and cli (cpu only) ---

ARG GO_VERSION=1.22.6
ARG ONNXRUNTIME_VERSION=1.18.0
ARG BUILD_PLATFORM=linux/amd64

#--- build layer ---

FROM --platform=$BUILD_PLATFORM public.ecr.aws/amazonlinux/amazonlinux:2023 AS hugot-build
ARG GO_VERSION
ARG ONNXRUNTIME_VERSION

# Copy go.mod and go.sum
COPY ./go.mod ./go.sum ./

# Install dependencies
RUN dnf -y install gcc jq bash tar xz gzip glibc-static libstdc++ wget zip git which && \
    ln -s /usr/lib64/libstdc++.so.6 /usr/lib64/libstdc++.so && \
    dnf clean all

# Install tokenizer library
RUN tokenizer_version=$(grep 'github.com/daulet/tokenizers' go.mod | awk '{print $2}') && \
    tokenizer_version=$(echo $tokenizer_version | awk -F'-' '{print $NF}') && \
    echo "tokenizer_version: $tokenizer_version" && \
    curl -LO https://github.com/daulet/tokenizers/releases/download/${tokenizer_version}/libtokenizers.linux-amd64.tar.gz && \
    tar -C /usr/lib -xzf libtokenizers.linux-amd64.tar.gz && \
    rm libtokenizers.linux-amd64.tar.gz

# Install Go
RUN curl -LO https://golang.org/dl/go${GO_VERSION}.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz && \
    rm go${GO_VERSION}.linux-amd64.tar.gz
ENV PATH="$PATH:/usr/local/go/bin"

# Install ONNX runtime CPU
RUN curl -LO https://github.com/microsoft/onnxruntime/releases/download/v${ONNXRUNTIME_VERSION}/onnxruntime-linux-x64-${ONNXRUNTIME_VERSION}.tgz && \
    tar -xzf onnxruntime-linux-x64-${ONNXRUNTIME_VERSION}.tgz && \
    mv ./onnxruntime-linux-x64-${ONNXRUNTIME_VERSION}/lib/libonnxruntime.so.${ONNXRUNTIME_VERSION} /usr/lib64/onnxruntime.so

# Build Go CLI binary
COPY . /build
WORKDIR /build
RUN CGO_ENABLED=1 CGO_LDFLAGS="-L/usr/lib/" GOOS=linux GOARCH=amd64 go build -a -o ./target/main main.go

#--- final layer ---
FROM --platform=$BUILD_PLATFORM public.ecr.aws/amazonlinux/amazonlinux:2023 AS final

WORKDIR /app

# Copy the executable and assets from the build stage
COPY --from=hugot-build /build/target/main /app/main
COPY --from=hugot-build /usr/lib/libtokenizers.a /usr/lib/libtokenizers.a
COPY --from=hugot-build /usr/lib64/onnxruntime.so /usr/lib64/onnxruntime.so

# Ensure the working directory is correct
WORKDIR /app

EXPOSE 8080

# Set the entrypoint to run the Go executable
CMD ["./main"]
  