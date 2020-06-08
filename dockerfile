FROM ubuntu:bionic
RUN apt-get update && apt-get install --assume-yes gdc ldc \
													libcurl4-gnutls-dev \
													wget libcurl4 gcc \
													curl gpg xz-utils
RUN wget http://downloads.dlang.org/releases/2.x/2.092.0/dmd_2.092.0-0_amd64.deb \
	&& dpkg --install dmd_2.092.0-0_amd64.deb \
	&& rm dmd_2.092.0-0_amd64.deb
RUN wget -O doveralls "https://github.com/ColdenCullen/doveralls/releases/download/v1.3.2/doveralls_linux_travis" \
	&& chmod +x doveralls
RUN wget https://dlang.org/install.sh \
	&& chmod +x install.sh
RUN ./install.sh install dmd-2.076.1
RUN ./install.sh install ldc-1.6.0
ADD . /code
RUN cd /code && dub test --compiler=/root/dlang/dmd-2.076.1/linux/bin64/dmd
RUN cd /code && dub test --compiler=/root/dlang/ldc-1.6.0/bin/ldc2
RUN cd /code && dub test --compiler=gdc
