FROM ubuntu:14.04

RUN locale-gen en_US.UTF-8
RUN dpkg-reconfigure locales
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8

RUN apt-get update; apt-get -y upgrade; apt-get clean
RUN apt-get install -y git curl wget tar make unzip; apt-get clean
RUN apt-get install -y realpath; apt-get clean
RUN apt-get install -y python3; apt-get clean;

# jq
RUN curl -L -o "/usr/local/bin/jq" "https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64" && \
    chmod +x "/usr/local/bin/jq"

# nodejs
RUN curl -sL https://deb.nodesource.com/setup_4.x | bash -; apt-get install -y nodejs; apt-get clean; rm -f /usr/bin/node; ln -s /usr/bin/nodejs /usr/bin/node

# azure CLI
RUN npm install -g azure-cli@0.10.10; azure -v

# chruby
RUN mkdir /tmp/chruby && \
    cd /tmp && \
    curl https://codeload.github.com/postmodern/chruby/tar.gz/v0.3.9 | tar -xz && \
    cd /tmp/chruby-0.3.9 && \
    sudo ./scripts/setup.sh && \
    rm -rf /tmp/chruby

# ruby-install
RUN mkdir /tmp/ruby-install && \
    cd /tmp && \
    curl https://codeload.github.com/postmodern/ruby-install/tar.gz/v0.6.0 | tar -xz && \
    cd /tmp/ruby-install-0.6.0 && \
    sudo make install && \
    rm -rf /tmp/ruby-install

# ruby
RUN ruby-install ruby 2.1.7

# Bundler
RUN /bin/bash -l -c "                            \
  source /etc/profile.d/chruby.sh ;              \
  chruby 2.1.7 ;                                 \
  gem install bundler --no-ri --no-rdoc          \
"

# certification tool
RUN cd /tmp && \
    curl -o certify-artifacts -L https://s3.amazonaws.com/bosh-certification-generator-releases/certify-artifacts-linux-amd64 && \
    chmod +x certify-artifacts && \
    mv certify-artifacts /bin/certify-artifacts
