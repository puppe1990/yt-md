#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "lib/yt_md"

begin
  YtMd::Cli.new.run(ARGV)
rescue ArgumentError, OptionParser::ParseError => error
  warn error.message
  exit 1
end
