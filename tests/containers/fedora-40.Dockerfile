FROM fedora:40
ENV container=docker
RUN dnf -y -q install systemd openssh-server openssh-clients procps-ng zsh dash diffutils && dnf clean all && \
    ssh-keygen -A && systemctl enable sshd && mkdir -p /root/.ssh && chmod 700 /root/.ssh
STOPSIGNAL SIGRTMIN+3
CMD ["/sbin/init"]
