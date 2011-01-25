# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "capita_git/version"

Gem::Specification.new do |s|
  s.name = "capita_git"
  s.version = CapitaGit::VERSION
  s.platform = Gem::Platform::RUBY
  s.authors = ["Sebastian Georgi"]
  s.email = ["sgeorgi@capita.de"]
  s.homepage = "https://github.com/capita/capita_git"
  s.summary = %q{Git-automation tool for managing features branches and more}
  s.description = %q{see RDoc or command help for further information}

  s.rubyforge_project = "capita_git"

  man_files = Dir.glob("lib/capita_git/man/**/*")
  s.files = `git ls-files`.split("\n") + man_files
  s.test_files = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables = `git ls-files -- bin/*`.split("\n").map { |f| File.basename(f) }
  s.require_paths = ["lib"]
  s.add_dependency('git', '>= 1.2.5')
  s.add_dependency('thor', '>= 0.14.6')
end
