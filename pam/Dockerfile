FROM registry.access.redhat.com/ubi8/ubi-init:latest

RUN mkdir -p /root/resources

ADD resources /root/resources

# Not all of the installed packages are strictly necessary, but can be useful
RUN dnf update  -y
RUN dnf install -y --nodocs openssl \
    openssh-server \
    zip unzip \
    vim \
    net-tools \
    jq
RUN dnf clean all
RUN rm -rf /var/cache/yum
RUN chmod 644 /etc/shadow
RUN cp /root/resources/very-last.service /etc/systemd/system/very-last.service 
RUN systemctl enable very-last
