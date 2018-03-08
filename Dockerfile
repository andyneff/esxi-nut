# I wanted a static "/bin/install"
FROM busybox:1.28.1-uclibc AS busybox





# All of the centos build utils in one place
FROM centos:6 AS dev_tools
SHELL ["/usr/bin/env", "bash", "-euvxc"]
RUN yum groupinstall -y "Development Tools"; \
    yum clean all





# I wanted to have glibc 2.12.2 EXACTLY, best practices and all :)
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

RUN mkdir -p /install/etc; \
    touch /install/etc/ld.so.conf; \
    mkdir -p /build/glibc; \
    cd /build/glibc; \
    echo "Configuring glibc (for the headers)"; \
    (/src/glibc-*/configure --prefix=/install 2>&1) | pv -f > /dev/null; \
    echo "Building glibc (for the headers)"; \
    (make -j `nproc` 2>&1) | pv -f -i 5 > /dev/null; \
    echo "Installing glibc (for the headers)"; \
    (make -j `nproc` install 2>&1) | pv -f -i 5 > /dev/null





# Rene Garcias' ups executable used the following libraries
# http://rene.margar.fr/2012/05/client-nut-pour-esxi-5-0/
# libz.so.1
# - 1.2.8
# - https://downloads.sourceforge.net/project/libpng/zlib/1.2.8/zlib-1.2.8.tar.gz

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





# Zlib wasn't needed in the end, I'm not using the CGI feature
# FROM centos:6 AS tools
# SHELL ["/usr/bin/env", "bash", "-euvxc"]
# ARG LIBZ_VERSION=1.2.8
# RUN mkdir -p /src; \
#     cd /src; \
#     curl -LO "https://downloads.sourceforge.net/project/libpng/zlib/${LIBZ_VERSION}/zlib-${LIBZ_VERSION}.tar.gz"; \
#     tar xf "zlib-${LIBZ_VERSION}.tar.gz"; \
#     rm "zlib-${LIBZ_VERSION}.tar.gz"
# COPY --from=tools /src/zlib-* /src/zlib
# COPY --from=tools /src/zlib-*/include /include This is wrong





# Download and prep Network UPS Tools Source
FROM dev_tools AS nut

SHELL ["/usr/bin/env", "bash", "-euvxc"]

ARG NUT_VERSION=2.7.4
RUN mkdir -p /src; \
    cd /src; \
    curl -L "https://github.com/networkupstools/nut/archive/v${NUT_VERSION}.tar.gz" -o "nut-${NUT_VERSION}.tar.gz"; \
    tar xf "nut-${NUT_VERSION}.tar.gz"; \
    rm "nut-${NUT_VERSION}.tar.gz"

# Run the python and perl part of the setup. It's just easier to do this here,
# esxi has python 3, and this script is python2 only
RUN cd /src/nut-*; \
    sh <(sed 's|^autoreconf.*||' ./autogen.sh)





# The main esxi build section
FROM andyneff/esxi

### Perl ###

# I decided to run autoreconf inside the esxi stage
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

### End of Perl ###
### GCC ###

COPY --from=glibc /install/include /include
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

                      # cc1 from cpp, collect2 from gcc
COPY --from=dev_tools /usr/libexec/gcc/x86_64-redhat-linux/4.4.4/* \
                      /bin/

                      # lib mpfr
COPY --from=dev_tools /usr/lib64/libmpfr.* \
                      # lib gmp
                      /usr/lib64/libgmp.* \
                      # binutils?
                      /usr/lib64/libopcodes*.so \
                      /usr/lib64/libbfd*.so \
                      # gcc
                      /usr/lib/gcc/x86_64-redhat-linux/4.4.4/*.o \
                      /usr/lib/gcc/x86_64-redhat-linux/4.4.4/*.a \
                      /lib64/
# Skipping ppl, cloog-ppl, and libgomp. Not needed?

                  # From my glibc that matches esxi exactly
COPY --from=glibc /install/lib/*.o \
                  /install/lib/*.a \
                  /install/lib/libc_nonshared.a \
                  /lib64/

                      # gcc
COPY --from=dev_tools /usr/bin/gcc \
                      # binutils
                      /usr/bin/ld \
                      /bin/

# Create an esxi appropriate libc.so ld script, or else shared linking fails
RUN echo "OUTPUT_FORMAT(elf64-x86-64)" > /lib64/libc.so; \
    echo "GROUP ( /lib64/libc.so.6 /lib64/libc_nonshared.a  AS_NEEDED ( /lib64/ld-linux-x86-64.so.2 ) )" >> /lib64/libc.so

### End of GCC ###
### Automake/make ###

COPY --from=dev_tools /usr/share/autoconf /usr/share/autoconf
COPY --from=dev_tools /usr/share/aclocal /usr/share/aclocal
COPY --from=dev_tools /usr/share/aclocal-1.11 /usr/share/aclocal-1.11
COPY --from=dev_tools /usr/share/automake-1.11 /usr/share/automake-1.11

# Centos install uses ESXi incompatible libselinux.so, so use busybox's
COPY --from=busybox /bin/install \
                    /bin/

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
# FINALLY! Network UPS Tools
COPY --from=nut /src/nut-* /src/nut

# Now, I only installed what I needed. So no usb, snmp, xml, avahi, powermane,
# ipmi, mac os x meta, i2c, ssl, libwrap, libltdl, nut-scanner, CGI (no gd),
# docs, or devel support. None of these are needed

RUN cd /src/nut; \
    autoreconf -i; \
    ./configure; \
    make man5_MANS= man8_MANS=
