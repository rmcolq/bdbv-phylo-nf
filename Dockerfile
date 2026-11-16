# Build stage: Python and Java from conda-forge, then BEAST's TreeAnnotator from the official release.
#
# Java and Python are installed from conda-forge, which has them for both amd64 and arm64. The bioconda
# `beast` package only exists for linux-64 and osx-64, so BEAST is not installed from conda. The BEAST
# release archive is just jars and launcher scripts (no bundled Java, no native code), so the same files
# work on every architecture. The download is checked against its SHA-256.
FROM condaforge/miniforge3:latest AS build

RUN mamba create -y -p /opt/env "python>=3.10" "openjdk=17" \
    && mamba clean -afy

# BEAST X v10.6.0, the current release (https://beast.community). To update, change the version in the URL
# and the SHA-256 together: the checksum is shown for each file on the GitHub release page.
ADD --checksum=sha256:9c5f255d7e6184af4b2a066eae3df07dd24e1dc35cb7cd13c8e4b73778526f33 \
    https://github.com/beast-dev/beast-mcmc/releases/download/v10.6.0/BEAST_X_v10.6.0.tgz /tmp/beast.tgz

RUN mkdir -p /opt/beast \
    && tar -xzf /tmp/beast.tgz -C /opt/beast --strip-components=1 \
        --wildcards '*/bin/*' '*/lib/*' \
    && ln -s /opt/beast/bin/treeannotator /opt/env/bin/treeannotator \
    && rm -rf /opt/env/jmods /opt/env/lib/src.zip

# Runtime stage: slim base with only the environment and BEAST copied over (no conda, no package cache)
FROM debian:bookworm-slim

# procps provides `ps`, which Nextflow uses to collect task metrics
RUN apt-get update \
    && apt-get install -y --no-install-recommends procps \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /opt/env /opt/env
COPY --from=build /opt/beast /opt/beast
COPY bin/ /opt/bdbv-pipeline-beast/bin/

# bin/ is copied for standalone use (call scripts by full path). It is deliberately not on PATH:
# Nextflow supplies the project's own bin/, which must not be shadowed by this copy.
ENV PATH=/opt/env/bin:$PATH

CMD ["/bin/bash"]
