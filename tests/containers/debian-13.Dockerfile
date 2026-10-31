FROM debian:13
ENV DEBIAN_FRONTEND=noninteractive container=docker
RUN apt-get update -q && apt-get install -y -q --no-install-recommends systemd systemd-sysv openssh-server openssh-client procps ca-certificates && \
    rm -f /etc/ssh/ssh_host_* && ssh-keygen -A && systemctl enable ssh && mkdir -p /root/.ssh && chmod 700 /root/.ssh
STOPSIGNAL SIGRTMIN+3
CMD ["/sbin/init"]
