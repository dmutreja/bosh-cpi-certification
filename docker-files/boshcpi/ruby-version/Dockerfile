FROM boshcpi/ruby-base:latest

ARG RUBY_VERSION

# Install Ruby
RUN ruby-install ruby $RUBY_VERSION -- --disable-install-rdoc

# Install Bundler
RUN /bin/bash -l -c "                            \
  source /etc/profile.d/chruby.sh ;              \
  chruby $RUBY_VERSION ;                         \
  gem install bundler --no-ri --no-rdoc          \
"
