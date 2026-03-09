FROM ubuntu:22.04

RUN apt-get update && \
    apt-get install -y openssh-server && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir /var/run/sshd

RUN echo 'root:testpass123' | chpasswd

RUN sed -i 's/#*PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#*PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/#*ChallengeResponseAuthentication no/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config && \
    sed -i 's/#*UsePAM yes/UsePAM yes/' /etc/ssh/sshd_config

EXPOSE 22

CMD ["/usr/sbin/sshd", "-D"]
