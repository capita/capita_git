# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "capita_git/version"

Gem::Specification.new do |s|
  s.name = "capita_git"
  s.version = CapitaGit::VERSION
  s.platform = Gem::Platform::RUBY
  s.authors = [": Write your name"]
  s.email = [": Write your email address"]
  s.homepage = ""
  s.summary = %q{: Write a gem summary}
  s.description = %q{: Write a gem description}

  s.rubyforge_project = "capita_git"

  man_files = Dir.glob("lib/capita_git/man/**/*")
  s.files = `git ls-files`.split("\n") + man_files
  s.test_files = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables = `git ls-files -- bin/*`.split("\n").map { |f| File.basename(f) }
  s.require_paths = ["lib"]
  s.add_dependency('git', '>= 1.2.5')
  s.add_dependency('thor', '>= 0.14.6')
end
