FROM ruby:2.7.3-alpine3.13

RUN mkdir -p /app/data
WORKDIR /app

RUN apk add --no-cache git curl bash
RUN apk add --no-cache --virtual build-dependencies build-base gcc && \
    gem install rspec activesupport google-cloud-storage pry redisgraph parallel fast_jsonparser && \
    apk del build-dependencies

ADD lib /app/lib
ADD Rakefile /app

CMD ["/bin/bash"]
