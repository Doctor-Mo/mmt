# This image provides the ability to run Ruby/RSpec tests against a Clojure app.
# To build:
# sudo docker build --rm --force-rm --tag=$(basename $(pwd)) .

FROM centos:centos7

# Get java, epel, whatnot
RUN yum install -y epel-release \
                   https://rpm.nodesource.com/pub_8.x/el/7/x86_64/nodesource-release-el7-1.noarch.rpm \
                   https://yum.postgresql.org/9.6/redhat/rhel-7-x86_64/pgdg-centos96-9.6-3.noarch.rpm \
 && yum --enablerepo=updates clean metadata \
 && yum install -y bzip2 \
                   clamav \
                   cmake \
                   chromedriver \
                   git \
                   gcc \
                   gcc-c++ \
                   https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm \
                   ImageMagick \
                   java-1.8.0-openjdk-headless.x86_64 \
                   liberation-fonts \
                   libffi-devel \
                   libicu-devel \
                   libxml2-devel \
                   make \
                   nodejs \
                   openssl-devel \
                   postgresql96-devel \
                   readline-devel \
                   sqlite-devel \
                   tar \
                   which \
                   xorg-x11-server-Xvfb \
 && yum clean all \ 
 && freshclam

ENV JAVA_HOME /etc/alternatives/jre

# Install Ruby from source
WORKDIR /
RUN curl -OL https://cache.ruby-lang.org/pub/ruby/2.5/ruby-2.5.1.tar.gz \
 && tar -xzf ruby-2.5.1.tar.gz \
 && rm ruby-2.5.1.tar.gz \
 && cd /ruby-2.5.1 \
 && ./configure --disable-install-doc \
 && make -j $(nproc) \
 && make install \
 && cd / \
 && rm -fr ruby-2.5.1

RUN gem install bundler --no-rdoc --no-ri --version 1.17.3
RUN gem update --system 2.7.8

RUN groupadd -g 500 bamboo
RUN useradd --gid bamboo --create-home --uid 500 bamboo

ENV PATH /usr/pgsql-9.6/bin:/opt/google/chrome:$PATH

USER bamboo
WORKDIR /build
#RUN whoami
#RUN pwd
#RUN ls -l /
#RUN touch test.owner.txt

#this should be writable to everyone.
#RUN ls -l /build/.bundle/config

#RUN bundle install --path=/build/vendor/bundle
#RUN su bamboo -c "bundle install --path=/build/vendor/bundle"
CMD bundle install --path=/build/vendor/bundle
CMD ./bin/rails s --binding 0.0.0.0

