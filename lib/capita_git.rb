module CapitaGit
  autoload :UI, 'capita_git/ui'
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
