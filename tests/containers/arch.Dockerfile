FROM archlinux:latest
ENV container=docker
RUN pacman -Syu --noconfirm --needed -q systemd openssh procps-ng diffutils zsh dash && pacman -Scc --noconfirm && \
    ssh-keygen -A && systemctl enable sshd && mkdir -p /root/.ssh && chmod 700 /root/.ssh
STOPSIGNAL SIGRTMIN+3
CMD ["/sbin/init"]
