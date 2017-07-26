FROM boshcpi/tools-base:latest

# Import Postmodern PGP key
RUN wget -nv https://raw.github.com/postmodern/postmodern.github.io/master/postmodern.asc && \
    gpg --import postmodern.asc && \
    gpg --fingerprint 0xB9515E77 | grep 'Key fingerprint = 04B2 F3EA 6541 40BC C7DA  1B57 54C3 D9E9 B951 5E77' && \
    if [ "$?" != "0" ]; then echo "Invalid PGP key!"; exit 1; fi

ENV RUBY_INSTALL_VERSION=0.6.1 CHRUBY_VERSION=0.3.9

# Install chruby
RUN cd /tmp && \
    wget -nv -O chruby-$CHRUBY_VERSION.tar.gz https://github.com/postmodern/chruby/archive/v$CHRUBY_VERSION.tar.gz && \
    wget -nv https://raw.github.com/postmodern/chruby/master/pkg/chruby-$CHRUBY_VERSION.tar.gz.asc && \
    gpg --verify chruby-$CHRUBY_VERSION.tar.gz.asc chruby-$CHRUBY_VERSION.tar.gz && \
    tar -xzvf chruby-$CHRUBY_VERSION.tar.gz && \
    cd chruby-$CHRUBY_VERSION/ && \
    sudo ./scripts/setup.sh && \
    rm -rf /tmp/chruby-$CHRUBY_VERSION && rm /tmp/*

# Install ruby-install
RUN cd /tmp && \
    wget -nv -O ruby-install-$RUBY_INSTALL_VERSION.tar.gz https://github.com/postmodern/ruby-install/archive/v$RUBY_INSTALL_VERSION.tar.gz && \
    wget -nv https://raw.github.com/postmodern/ruby-install/master/pkg/ruby-install-$RUBY_INSTALL_VERSION.tar.gz.asc && \
    gpg --verify ruby-install-$RUBY_INSTALL_VERSION.tar.gz.asc ruby-install-$RUBY_INSTALL_VERSION.tar.gz && \
    tar -xzvf ruby-install-$RUBY_INSTALL_VERSION.tar.gz && \
    cd ruby-install-$RUBY_INSTALL_VERSION/ && \
    sudo make install && \
    rm -rf /tmp/ruby-install-$RUBY_INSTALL_VERSION && rm /tmp/*
