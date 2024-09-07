FROM golang:1.23.1 as go-builder

WORKDIR /app
USER root

ADD ./scripts/setup_measured_boot.sh /app/setup_measured_boot
RUN chmod +x /app/

ADD ./scripts/setup_git.sh /app/setup_git
RUN chmod +x /app/setup_git

CMD /app/setup_git; /app/setup_measured_boot

FROM crops/poky@sha256:f51ae3279f98768514273061336421e686e13d0a42fdb056c0b88c9afeec8c56 as builder

ENV DOCKER_BUILD=true

USER root
RUN apt install -y repo

COPY --from=go-builder /app/measured-boot/measured-boot /usr/bin/measured-boot

ADD ./scripts/setup_git.sh /usr/bin/setup_git
RUN chmod +x /usr/bin/setup_git

ADD ./scripts/build.sh /usr/bin/build
RUN chmod +x /usr/bin/build

ADD ./scripts/measure.sh /usr/bin/measure
RUN chmod +x /usr/bin/measure

ADD ./patches /patches
ADD ./meta-nethermind /meta-nethermind
ADD ./meta-lighthouse-bin /meta-lighthouse-bin

CMD /usr/bin/setup_git; /usr/bin/build; /usr/bin/measure
