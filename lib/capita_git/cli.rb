require 'thor'
require 'thor/actions'
require 'rubygems/config_file'

Gem.configuration

module CapitaGit
  class CLI < Thor
    include Thor::Actions

    def initialize(*)
      super
      the_shell = (options["no-color"] ? Thor::Shell::Basic.new : shell)
      CapitaGit.ui = CapitaGit::UI::Shell.new(the_shell)
      CapitaGit.ui.debug! if options["verbose"]
      Gem::DefaultUserInteraction.ui = CapitaGit::UI::RGProxy.new(CapitaGit.ui)
    end

    check_unknown_options! unless ARGV.include?("exec") || ARGV.include?("config")

    class_option "no-color", :type => :boolean, :banner => "Disable colorization in output"
    class_option "verbose", :type => :boolean, :banner => "Enable verbose output mode", :aliases => "-V"

    def help(cli = nil)
      case cli
        when "gemfile" then
          command = "gemfile.5"
        when nil then
          command = "gitc"
        else
          command = "gitc-#{cli}"
      end

      manpages = %w(
              gitc
              gitc-check)

      if manpages.include?(command)
        root = File.expand_path("../man", __FILE__)

        if have_groff? && root !~ %r{^file:/.+!/META-INF/jruby.home/.+}
          groff = "groff -Wall -mtty-char -mandoc -Tascii"
          pager = ENV['MANPAGER'] || ENV['PAGER'] || 'more'

          Kernel.exec "#{groff} #{root}/#{command} | #{pager}"
        else
          puts File.read("#{root}/#{command}.txt")
        end
      else
        super
      end
    end

    method_option 'remote', :type => :string
    desc "check", "Generates a Gemfile into the current working directory"
    def check
      opts = options.dup
      log :debug, "[DEBUG] Starting action 'check'"

      repo = CapitaGit::Repository.open(Dir.pwd, CapitaGit.ui)
      repo.git_remote = opts[:remote] if opts[:remote]
      log :debug, "[DEBUG] Repository remote set to '#{repo.git_remote}'"

      log :info, "-- Starting to check repository '#{repo.name}'"
      log :confirm, "-> Active user   : '#{repo.user_name} <#{repo.user_email}>'"
      log :confirm, "-> User shortcut : '#{repo.user_shortcut}'"
      log :info, "\n"

      log :info, "-- Checking for latest changes on \'#{repo.remote}\'"
      repo.fetch_remote_changes
      latest_major_release_tag = repo.latest_major_release_tag
      latest_minor_release_tag = repo.latest_minor_release_tag
      log :confirm, "-> Latest major release tag is: #{latest_major_release_tag || '---'}"
      log :confirm, "-> Latest minor release tag is: #{latest_minor_release_tag || '---'}"
      log :info, "\n"

      if latest_major_release_tag.nil?
        log :warn, 'No major release tag found, exiting!'
        exit 0
      end

      log :info, '-- Checking for presence of major release fixbranch'
      local_fixbranch = repo.local_fixbranch_for_version?(latest_major_release_tag)
      remote_fixbranch = repo.remote_fixbranch_for_version?(latest_major_release_tag)
      log :confirm, "-> Local  : #{local_fixbranch.nil? ? '---' : local_fixbranch.full }"
      log :confirm, "-> Remote : #{remote_fixbranch.nil? ? '---' : remote_fixbranch.full }"

      if not repo.has_remote_fixbranch_for_version?(latest_major_release_tag)
        log :info, "--> Creating remote fixbranch #{latest_major_release_tag}-fix"
        repo.create_remote_fixbranch_for_version(latest_major_release_tag)
      end

      if not repo.has_local_fixbranch_for_version?(latest_major_release_tag)
        log :info, "--> Creating tracking local fixbranch #{latest_major_release_tag}-fix from remote fixbranch"
        repo.create_local_fixbranch_for_version(latest_major_release_tag)
      end

      log :info, "\n-- Done!\n"
    end

    desc "create", "Creates a new feature branch with the given name and optional source branch"
    def create(name, source=nil)
      repo = CapitaGit::Repository.open(Dir.pwd)
      source = source.nil? ? repo.current_branch.to_s : source
      log :confirm, "--> Creating and switching to feature branch '#{repo.user_shortcut}_#{source}_#{name}'"
      repo.create_local_branch("#{repo.user_shortcut}_#{source}_#{name}", source)
      repo.checkout_local_branch("#{repo.user_shortcut}_#{source}_#{name}")
    end

    desc "update", "Updates a feature branch your currently on or specified by name"

    def update(name=nil)
      repo = CapitaGit::Repository.open(Dir.pwd)
      name = name.nil? ? repo.current_branch : name
      raise "Source branch '#{name}' does not exist" unless repo.has_local_branch?(name)
      raise "Source branch '#{name}' is not a feature branch, can't update!" unless repo.is_local_feature_branch?(name)

      log :confirm, "--> Updating feature branch '#{name}' from '#{repo.source_branch(name)}'"
      repo.rebase_local_branch(name)
    end

    desc "close", "Closes a feature branch your currently on or specified by name onto the source branch"

    def close(name=nil)
      repo = CapitaGit::Repository.open(Dir.pwd)
      name = name.nil? ? repo.current_branch : name
      raise "Source branch '#{name}' does not exist" unless repo.has_local_branch?(name)
      raise "Source branch '#{name}' is not a feature branch, can't close!" unless repo.is_local_feature_branch?(name)

      log :confirm, "--> Closing feature branch '#{name}' onto '#{repo.source_branch(name)}'"
      repo.close_local_branch(name)
    end

    desc "runner", "Generates a Gemfile into the current working directory"

    def runner(command)
      repo = CapitaGit::Repository.open(Dir.pwd)
      puts repo.send("#{command}")
    end

    private

    def log(level, message)
      CapitaGit.ui.send(level, message)
    end

    def have_groff?
      !(`which groff` rescue '').empty?
    end
  end
end
