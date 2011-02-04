$:.unshift File.expand_path(__FILE__)
require 'rubygems'
require 'capita_git/cli'
require 'capita_git/repository'
require 'capita_git/ui'
require 'capita_git/version'

module CapitaGit
  class << self
    attr_writer :ui

    def ui
      @ui ||= UI.new
    end
  end

  def self.do
    puts "Working"
  end

  class UncleanError < StandardError
  end

  class RepositoryError < StandardError
  end
end

Gem.post_install do |installer|
  puts "!!! #{installer.spec.full_name} INSTALLED !!!"
end
