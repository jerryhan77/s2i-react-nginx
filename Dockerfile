FROM centos:centos7

MAINTAINER Julian Tescher <julian@outtherelabs.com>

# Current stable version
ENV NGINX_VERSION=1.10.2

# Set labels used in OpenShift to describe the builder images
LABEL io.k8s.description="Platform for serving frontend React apps" \
      io.k8s.display-name="Create React App" \
      io.openshift.expose-services="8080:http" \
      io.openshift.tags="builder,html,nginx"

# Add yum repo for nginx
ADD etc/nginx.repo /etc/yum.repos.d/nginx.repo

# Install the current version, node and yarn
RUN yum install -y wget && \
    curl --silent --location https://rpm.nodesource.com/setup_16.x | bash - && \
    wget https://dl.yarnpkg.com/rpm/yarn.repo -O /etc/yum.repos.d/yarn.repo && \
    yum install -y --setopt=tsflags=nodocs nginx-$NGINX_VERSION && \
    yum install -y nodejs yarn gcc-c++ make && \
    yum clean all -y

# Install source to image
COPY ./.s2i/bin/ /usr/libexec/s2i
#COPY --chmod=755 ./.s2i/bin/ /usr/libexec/s2i

# Copy the nginx config file
COPY ./etc/nginx.conf /etc/nginx/conf.d/default.conf

RUN mkdir /.config && chown -R 1001:1001 /.config && \
    mkdir /.cache && chown -R 1001:1001 /.cache && \
    chmod 755 /usr/libexec/s2i/* && \
    chmod -R 777 /var/log/nginx /var/cache/nginx/ \
    && chmod 777 /var/run \
    && chmod 644 /etc/nginx/* \
    && chmod 755 /etc/nginx/conf.d \
    && chmod 644 /etc/nginx/conf.d/default.conf

# Set to non root user provided by parent image
USER 1001

# Expose port 8080
EXPOSE 8080

# Run usage command by default
CMD ["/usr/libexec/s2i/usage"]
