FROM ruby:3.1.3-bullseye

RUN gem install bundler rails rake

RUN mkdir /app
ENV RAILS_ROOT /app
WORKDIR /app

EXPOSE 3000
