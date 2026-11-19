FROM quay.io/rockylinux/rockylinux:9.8

RUN dnf makecache && dnf install -y --allowerasing \
        java-17-openjdk-devel \
        openssh-server \
        openssh-clients \
        rsync \
        wget \
        curl \
        tar \
        gzip \
        procps-ng \
        hostname \
        iproute \
        diffutils \
        which \
        sudo \
        chrony \
        iputils \
    && dnf clean all \
    && ssh-keygen -A \
    && mkdir -p /var/run/sshd /root/.ssh /opt/hadoop /data/hadoop/tmp /data/hadoop/dfs/name /data/hadoop/dfs/data \
    && chmod 700 /root/.ssh \
    && ssh-keygen -t ed25519 -N '' -f /root/.ssh/id_ed25519 \
    && cp /root/.ssh/id_ed25519.pub /root/.ssh/authorized_keys \
    && chmod 600 /root/.ssh/authorized_keys \
    && printf 'Host namenode datanode1 datanode2\n  StrictHostKeyChecking accept-new\n' > /root/.ssh/config \
    && (id hadoop || useradd -m -s /bin/bash hadoop) \
    && echo 'hadoop:hadoop' | chpasswd \
    && chown -R hadoop:hadoop /opt/hadoop /data/hadoop \
    && chmod 755 /opt/hadoop /data/hadoop \
    && printf 'hadoop ALL=(ALL) NOPASSWD:ALL\n' > /etc/sudoers.d/hadoop \
    && chmod 440 /etc/sudoers.d/hadoop \
    && printf '\nUseDNS no\nPasswordAuthentication yes\nPubkeyAuthentication yes\nPermitRootLogin prohibit-password\n' >> /etc/ssh/sshd_config

COPY entrypoint.sh /entrypoint.sh
RUN sed -i 's/\r$//' /entrypoint.sh && chmod 755 /entrypoint.sh

EXPOSE 22 8020 9870 8088 19888
ENTRYPOINT ["/entrypoint.sh"]
