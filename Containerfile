# discrolless by KiKaraage

# A: Copy build script 
FROM scratch AS ctx
COPY build.sh /build.sh

# References when copying from other OCI containers to avoid conflicts is necessary
# Note: Renovate can automatically update these :latest tags to SHA-256 digests for reproducibility
# COPY --from=ghcr.io/projectbluefin/common:latest /system_files /oci/common
# COPY --from=ghcr.io/ublue-os/brew:latest /system_files /oci/brew

# B: Build from Bluefin as base image and run build script to modify it
FROM ghcr.io/projectbluefin/distroless:latest

# Fix OSTree /etc conflict - remove /usr/etc if it exists (keep /etc as directory)
RUN rm -rf /usr/etc

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh
    
# C: Verify final image and contents are correct
RUN bootc container lint
