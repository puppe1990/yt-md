# frozen_string_literal: true

require "rake/testtask"

Rake::TestTask.new(:test) do |task|
  task.libs << "lib"
  task.test_files = FileList["test/**/*_test.rb"]
end

task default: :test

desc "Fail when any lib method has CRAP >= 10 (needs coverage/.resultset.json)"
task :crap do
  ruby "bin/crap --threshold 10"
end

desc "Fail when lib methods duplicate at rank >= 0.8"
task :dry do
  ruby "bin/dry --threshold 0.8"
end

desc "Swap &&/|| in lib one site at a time and rerun the suite"
task :mutate do
  ruby "bin/mutate"
end
