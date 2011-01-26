require 'rubygems'
require 'bundler/setup'
require 'capita_git'

require 'test/unit'
require 'shoulda'

require 'fileutils'
require "open4" # See http://tech.natemurray.com/2007/03/ruby-shell-commands.html
require 'shoulda_macros'

class Test::Unit::TestCase
  include ShouldaMacros::InstanceMethods
  extend  ShouldaMacros::ClassMethods
  
  # Make sure the temporary directory is purged after every run
  def teardown
    FileUtils.rm_rf(temp_dir)
  end
end
