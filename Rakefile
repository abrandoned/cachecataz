#!/usr/bin/env rake
require "bundler/gem_tasks"

begin 
  require "rspec"
  require "rspec/core/rake_task"

  RSpec::Core::RakeTask.new(:spec) do |t|
    t.rspec_opts = "--color"
  end

  task :default => [:spec]
rescue
  puts "RSpec is not loaded"
end
