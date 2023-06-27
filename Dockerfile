#FROM redhat/ubi8
#FROM centos:centos8
FROM quay.io/centos/centos:stream8

MAINTAINER Julian Tescher <julian@outtherelabs.com>

# Current stable version
ENV NGINX_VERSION=1.18.0 \
    HOME=/opt/app-root/src \
    BASH_ENV=/opt/app-root/etc/scl_enable \
    ENV=/opt/app-root/etc/scl_enable \
    STI_SCRIPTS_URL=image:///usr/libexec/s2i \
    STI_SCRIPT_PATH=/usr/libexec/s2i \
    PATH=/opt/app-root/src/bin:/opt/app-root/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Set labels used in OpenShift to describe the builder images
LABEL io.k8s.description="Platform for serving frontend React apps" \
      io.k8s.display-name="Create React App" \
      io.openshift.expose-services="8080:http" \
      io.openshift.tags="builder,html,nginx"

# Add yum repo for nginx
ADD etc/nginx.repo /etc/yum.repos.d/nginx.repo

# Install the current version, node and yarn
RUN yum install -y wget && \
    curl --silent --location https://rpm.nodesource.com/setup_20.x | bash - && \
    wget https://dl.yarnpkg.com/rpm/yarn.repo -O /etc/yum.repos.d/yarn.repo && \
    yum install -y --setopt=tsflags=nodocs nginx && \
    yum install -y nodejs yarn gcc-c++ make && \
    yum clean all -y

# Install source to image
COPY ./.s2i/bin/ /usr/libexec/s2i

# Copy the nginx config file
COPY ./etc/nginx.conf /etc/nginx/conf.d/default.conf

RUN mkdir /.config && chown -R 1001:1001 /.config && \
    mkdir /.cache && chown -R 1001:1001 /.cache && \
    mkdir -p /opt/app-root/src && mkdir /opt/app-root/etc && chown -R 1001 /opt/app-root && \
    chmod 755 /usr/libexec/s2i/* && \
    chmod -R 777 /var/log/nginx \
    && chmod 777 /var/run \
    && chmod 644 /etc/nginx/* \
    && chmod 755 /etc/nginx/conf.d \
    && chmod 644 /etc/nginx/conf.d/default.conf

COPY --chown=1001 ./etc/scl_enable /opt/app-root/etc/scl_enable


# Set to non root user provided by parent image
USER 1001

# Expose port 8080
EXPOSE 8080

# Run usage command by default
CMD ["/usr/libexec/s2i/usage"]
