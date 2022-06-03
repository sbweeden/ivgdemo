FROM registry.access.redhat.com/ubi8/ubi-init:latest

RUN mkdir -p /root/resources

ADD resources /root/resources

# Not all of the installed packages are strictly necessary, but can be useful
RUN dnf update \
 && dnf install -y --nodocs openssl \
    openssh-server \
    zip unzip \
    vim \
    net-tools \
    jq \
 && dnf clean all \
 && rm -rf /var/cache/yum \
 && cp /root/resources/very-last.service /etc/systemd/system/very-last.service \
 && systemctl enable very-last

# Its better you configure and run the setup script manually by exec'ing into the 
# running demo container rather than making it part of the container build as
# otherwise you are burning secrets into the container - bad practice
#RUN /bin/sh /root/resources/setup_ivg_pam.sh

