FROM registry.access.redhat.com/ubi8/ubi-init:latest

RUN mkdir -p /root/resources

ADD resources /root/resources

# Not all of the installed packages are strictly necessary, but can be useful
RUN dnf update  -y
RUN dnf install -y --nodocs \
    zip unzip \
    vim \
    net-tools \
    nmap \
    perl \
    jq
RUN export PERL_MM_USE_DEFAULT=1 && cpan Authen::Radius
RUN dnf clean all && rm -rf /var/cache/yum
RUN cp /root/resources/very-last.service /etc/systemd/system/very-last.service && systemctl enable very-last

