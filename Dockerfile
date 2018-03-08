FROM busybox:1.28.1-uclibc AS busybox

FROM centos:6 AS dev_tools
SHELL ["/usr/bin/env", "bash", "-euvxc"]
RUN yum groupinstall -y "Development Tools"; \
    yum clean all

FROM dev_tools as glibc

RUN yum install -y epel-release; \
    yum install -y pv; \
    yum clean all

ARG GLIBC_VERSION=2.12.2
RUN mkdir /src; \
    cd /src; \
    curl -LO "https://ftp.gnu.org/gnu/glibc/glibc-${GLIBC_VERSION}.tar.gz"; \
    tar xf "glibc-${GLIBC_VERSION}.tar.gz"; \
    rm "glibc-${GLIBC_VERSION}.tar.gz"

RUN mkdir -p /src/glibc/etc; \
    touch /src/glibc/etc/ld.so.conf; \
    mkdir -p /build/glibc; \
    cd /build/glibc; \
    echo "Configuring glibc (for the headers)"; \
    (/src/glibc-*/configure --prefix=/src/glibc 2>&1) | pv -f > /dev/null; \
    echo "Building glibc (for the headers)"; \
    (make -j `nproc` 2>&1) | pv -f -i 5 > /dev/null; \
    echo "Installing glibc (for the headers)"; \
    (make -j `nproc` install 2>&1) | pv -f -i 5 > /dev/null

# FROM centos:6 AS tools

# SHELL ["/usr/bin/env", "bash", "-euvxc"]

# ARG LIBZ_VERSION=1.2.8
# RUN mkdir -p /src; \
#     cd /src; \
#     curl -LO "https://downloads.sourceforge.net/project/libpng/zlib/${LIBZ_VERSION}/zlib-${LIBZ_VERSION}.tar.gz"; \
#     tar xf "zlib-${LIBZ_VERSION}.tar.gz"; \
#     rm "zlib-${LIBZ_VERSION}.tar.gz"

FROM dev_tools AS nut

SHELL ["/usr/bin/env", "bash", "-euvxc"]

ARG NUT_VERSION=2.7.4
RUN mkdir -p /src; \
    cd /src; \
    curl -L "https://github.com/networkupstools/nut/archive/v${NUT_VERSION}.tar.gz" -o "nut-${NUT_VERSION}.tar.gz"; \
    tar xf "nut-${NUT_VERSION}.tar.gz"; \
    rm "nut-${NUT_VERSION}.tar.gz"

RUN cd /src/nut-*; \
    sh <(sed 's|^autoreconf.*||' ./autogen.sh)
# libz.so.1
# - 1.2.8
# https://downloads.sourceforge.net/project/libpng/zlib/1.2.8/zlib-1.2.8.tar.gz

# libc.so.6
# - 2.12.2
# - https://ftp.gnu.org/gnu/glibc/glibc-2.12.2.tar.gz
# - includes libpthread.so.0
# - includes librt.so.1
# - includes libdl.so.2
# - include libresolv.so.2 ?!

# nut
# - 2.7.4
# - https://github.com/networkupstools/nut/archive/v2.7.4.tar.gz
# - includes libupsclient.so.4

FROM andyneff/esxi AS esxi_perl

COPY --from=dev_tools /usr/share/perl5 /usr/share/perl5
COPY --from=dev_tools /usr/lib64/perl5 /usr/lib64/perl5
COPY --from=dev_tools /usr/bin/perl* \
                      /usr/bin/a2p \
                      /usr/bin/c2ph \
                      /usr/bin/dprofpp \
                      /usr/bin/find2perl \
                      /usr/bin/h2ph \
                      /usr/bin/piconv \
                      /usr/bin/pl2pm \
                      /usr/bin/pod* \
                      /usr/bin/psed \
                      /usr/bin/pstruct \
                      /usr/bin/s2p \
                      /usr/bin/splain \
                      /bin/


FROM esxi_perl
# FROM andyneff/esxi

# COPY --from=tools /usr/include \
#                   /cent_include

### GCC ###

COPY --from=glibc /src/glibc/include /include
COPY --from=dev_tools /usr/lib/gcc/x86_64-redhat-linux/4.4.4/include /lib/gcc/x86_64-redhat-linux/4.4.7/include

# Copy kernel headers... Should be "good enough"
COPY --from=dev_tools /usr/include/asm /include/asm
COPY --from=dev_tools /usr/include/asm-generic /include/asm-generic
COPY --from=dev_tools /usr/include/drm /include/drm
COPY --from=dev_tools /usr/include/linux /include/linux
COPY --from=dev_tools /usr/include/mtd /include/mtd
COPY --from=dev_tools /usr/include/rdma /include/rdma
COPY --from=dev_tools /usr/include/sound /include/sound
COPY --from=dev_tools /usr/include/uapi /include/uapi
COPY --from=dev_tools /usr/include/video /include/video
COPY --from=dev_tools /usr/include/xen /include/xen

COPY --from=dev_tools /usr/libexec/gcc/x86_64-redhat-linux/4.4.4/* \
                      /bin/

COPY --from=dev_tools /usr/lib64/libmpfr.* \
                      /usr/lib64/libgmp.* \
                      /usr/lib64/libopcodes*.so \
                      /usr/lib64/libbfd*.so \
                      /usr/lib/gcc/x86_64-redhat-linux/4.4.4/*.o \
                      /usr/lib/gcc/x86_64-redhat-linux/4.4.4/*.a \
                      /lib64/

COPY --from=glibc /src/glibc/lib/*.o \
                  /src/glibc/lib/*.a \
                  /lib64/

COPY --from=dev_tools /usr/bin/gcc \
                      /usr/bin/ld \
                      /bin/


### End of GCC ###

### Automake/make ###

COPY --from=dev_tools /usr/share/autoconf /usr/share/autoconf
COPY --from=dev_tools /usr/share/aclocal /usr/share/aclocal
COPY --from=dev_tools /usr/share/aclocal-1.11 /usr/share/aclocal-1.11

COPY --from=busybox /bin/install \
                    /bin/

COPY --from=dev_tools /usr/share/automake-1.11 /usr/share/automake-1.11

COPY --from=dev_tools /usr/share/libtool /usr/share/libtool
COPY --from=dev_tools /usr/bin/make \
                      /usr/bin/autoreconf \
                      /usr/bin/autom4te \
                      /usr/bin/aclocal \
                      /usr/bin/libtool \
                      /usr/bin/m4 \
                      /usr/bin/autoconf \
                      /usr/bin/libtoolize \
                      /usr/bin/tr \
                      /usr/bin/as \
                      /usr/bin/ar \
                      /usr/bin/autoheader \
                      /usr/bin/automake \
                      /bin/

### End of Automake ###

### g++

COPY --from=dev_tools /usr/bin/g++ \
                      /usr/bin/c++ \
                      /bin/

COPY --from=dev_tools /usr/include/c++/4.4.4 \
                      /include/c++/4.4.7

### End of g++ ###

### Other useful debugging tools ###

COPY --from=dev_tools /usr/bin/readelf \
                      /usr/bin/ldd \
                      /bin/


RUN sed -i 's|/bin/bash|/bin/sh|' /bin/ldd; \
    ln -s /include /usr/include

### End of tools ###

# COPY --from=tools /src/zlib-* /src/zlib
# COPY --from=tools /src/zlib-*/include /include


# FINALLY! Network UPS Tools

COPY --from=nut /src/nut-* /src/nut

RUN echo  $'#include <stdio.h>\nint main(){printf("hiya\\n"); return 0;}' > /hello.c

# RUN mv /bin/gcc /bin/gcc_orig; \
#     echo '/bin/gcc_orig -static "${@}"' > /bin/gcc; \
#     chmod 755 /bin/gcc

RUN cd /src/nut; \
    echo '/bin/gcc -static "${@}"' > /src/nut/gcc ; \
    chmod 755 /src/nut/gcc; \
    export CC=/src/nut/gcc; \
    autoreconf -i; \
    ./configure --disable-shared; \
    make man5_MANS= man8_MANS=
