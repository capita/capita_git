$:.unshift File.expand_path(__FILE__)
require 'rubygems'

module CapitaGit
  autoload :UI, 'capita_git/ui'
  autoload :CLI,'capita_git/cli'
  autoload :Repository, 'capita_git/repository'

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
end
