FROM ruby:3.3-slim

RUN apt-get update -qq && \
  apt-get install -y --no-install-recommends \
    build-essential \
    git \
    libpq-dev \
    pkg-config && \
  rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN gem install bundler --no-document

