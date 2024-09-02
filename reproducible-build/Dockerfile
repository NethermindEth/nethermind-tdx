FROM crops/poky@sha256:f51ae3279f98768514273061336421e686e13d0a42fdb056c0b88c9afeec8c56 as builder

ENV DOCKER=true

USER root
RUN apt install -y repo

ADD ../scripts/setup_git.sh /usr/bin/setup_git
RUN chmod +x /usr/bin/setup_git

ADD ../scripts/build.sh /usr/bin/build
RUN chmod +x /usr/bin/build

ADD ../patches /patches
ADD ../meta-nethermind /meta-nethermind

CMD /usr/bin/setup_git
CMD /usr/bin/build
