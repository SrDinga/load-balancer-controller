# syntax=docker/dockerfile:experimental

FROM --platform=${TARGETPLATFORM} debian:11-slim AS base

WORKDIR /workspace
# Copy the Go Modules manifests
COPY go.mod go.mod
COPY go.sum go.sum
# cache deps before building and copying source so that we don't need to re-download as much
# and so that source changes don't invalidate our downloaded layer


  
RUN --mount=type=bind,target=/path ls /path \
    --mount=type=cache,target=/root/.cache/go-build \
    GOPROXY=direct go mod download

FROM base AS build
ARG TARGETOS=linux
ARG TARGETARCH=amd64
ENV VERSION_PKG=sigs.k8s.io/aws-load-balancer-controller/pkg/version
RUN --mount=type=bind,target=/path ls /path \
RUN --mount=type=cache,target=/root/.cache/go-build \
    GIT_VERSION=$(git describe --tags --dirty --always) && \
    GIT_COMMIT=$(git rev-parse HEAD) && \
    BUILD_DATE=$(date +%Y-%m-%dT%H:%M:%S%z) && \
    GOOS=${TARGETOS} GOARCH=${TARGETARCH} GO111MODULE=on \
  
    CGO_CPPFLAGS="-D_FORTIFY_SOURCE=2" \
    CGO_LDFLAGS="-Wl,-z,relro,-z,now" \
    go build -buildmode=pie -tags 'osusergo,netgo,static_build' -ldflags="-s -w -linkmode=external -extldflags '-static-pie' -X ${VERSION_PKG}.GitVersion=${GIT_VERSION} -X ${VERSION_PKG}.GitCommit=${GIT_COMMIT} -X ${VERSION_PKG}.BuildDate=${BUILD_DATE}" -mod=readonly -a -o /out/controller main.go

FROM debian:11-slim as bin-unix
COPY --from=build /out/controller /controller
ENTRYPOINT ["/controller"]

FROM bin-unix AS bin-linux
FROM bin-unix AS bin-darwin

FROM bin-${TARGETOS} as bin


# RUN \
# 	--mount=type=cache,target=/root/.cache/go-build \
# 	--mount=type=cache,target=/go/pkg/mod \
# 	set -ex && \
# 		go build -gcflags=all="-N -l" \
# 			-o /usr/local/concourse/bin/concourse \
# 			./cmd/concourse && \
# 		gcc -O2 -static \
# 			-o /usr/local/concourse/bin/init \
# 			./cmd/init/init.c