#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "lib/yt_md"

$stdout.sync = true

begin
  YtMd::Cli.new.run(ARGV)
rescue ArgumentError, OptionParser::ParseError => e
  warn e.message
  exit 1
end
