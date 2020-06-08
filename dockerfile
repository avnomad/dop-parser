# - Creates an isolated build environment to test whether the toolchain
#   requirements stated in dub.sdl are up to date.
# - The image should build successfully if and only if the project is buildable
#   with the stated minimum versions of all 3 toolchains.
# - The build environment should be as close as possible to the one used by
#   Travis CI builds to help run experiments and predict whether the continuous
#   integration builds will succeed or fail.
FROM ubuntu:bionic
RUN apt-get update && apt-get install --assume-yes gdc ldc \
													libcurl4-gnutls-dev \
													wget libcurl4 gcc \
													curl gpg xz-utils
# Latest dmd isn't currently used but the package is installed to get the latest
# version of dub.
RUN wget http://downloads.dlang.org/releases/2.x/2.092.0/dmd_2.092.0-0_amd64.deb \
	&& dpkg --install dmd_2.092.0-0_amd64.deb \
	&& rm dmd_2.092.0-0_amd64.deb
# doveralls isn't actually used. It's only installed to check whether it can run
# without problems as in some systems (including TravisCI) it fails to find the
# required shared libraries.
RUN wget -O doveralls "https://github.com/ColdenCullen/doveralls/releases/download/v1.3.2/doveralls_linux_travis" \
	&& chmod +x doveralls && (./doveralls || [ $? -eq 1 ])
# Install official D compiler version manager. It will be used to fetch desired
# compiler versions for dmd and ldc. For gdc the system version will be used as
# install.sh can't currently fetch a recent one.
RUN wget https://dlang.org/install.sh \
	&& chmod +x install.sh
RUN ./install.sh install dmd-2.076.1
RUN ./install.sh install ldc-1.6.0
# Add source and project files and run one build with each toolchain.
ADD . /code
RUN cd /code && dub test --compiler=/root/dlang/dmd-2.076.1/linux/bin64/dmd
RUN cd /code && dub test --compiler=/root/dlang/ldc-1.6.0/bin/ldc2
RUN cd /code && dub test --compiler=gdc
