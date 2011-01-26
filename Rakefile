$:.unshift File.expand_path("../lib", __FILE__)
require 'bundler/gem_helper'
Bundler::GemHelper.install_tasks

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

task :default => :test

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

task :install => ["man:clean", "man:build"]
task :build => ["man:clean", "man:build"]
task :release => ["man:clean", "man:build"]

namespace :man do
  directory "lib/capita_git/man"

  ENV['RONN_MANUAL']  = "GITC Manual"
  ENV['RONN_ORGANIZATION'] = "GITC #{CapitaGit::VERSION}"

  Dir["man/*.ronn"].each do |ronn|
    basename = File.basename(ronn, ".ronn")
    roff = "lib/capita_git/man/#{basename}"

    file roff => ["lib/capita_git/man", ronn] do
      sh "ronn --roff --pipe #{ronn} > #{roff}"
    end

    file "#{roff}.txt" => roff do
      sh "groff -Wall -mtty-char -mandoc -Tascii #{roff} | col -b > #{roff}.txt"
    end

    task :build_all_pages => "#{roff}.txt"
  end

  desc "Build the man pages"
  task :build => "man:build_all_pages"

  desc "Clean up from the built man pages"
  task :clean do
    rm_rf "lib/capita_git/man"
  end
end
