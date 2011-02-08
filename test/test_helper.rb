require 'rubygems'
require 'bundler/setup'
require 'simplecov'
SimpleCov.start do
  add_filter "/test/"
end


require 'capita_git'
require 'git'

# Test-related libraries
require 'test/unit'
require 'shoulda'
require 'fileutils'
require "open4" # See http://tech.natemurray.com/2007/03/ruby-shell-commands.html
require 'shoulda_macros'

class Test::Unit::TestCase
  include ShouldaMacros::InstanceMethods
  extend  ShouldaMacros::ClassMethods
end
