$:.unshift File.expand_path("../lib", __FILE__)
require 'bundler/gem_helper'
Bundler::GemHelper.install_tasks

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
