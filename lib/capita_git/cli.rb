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

    desc "check", "Generates a Gemfile into the current working directory"

    def check
      repo = CapitaGit::Repository.open(Dir.pwd)
      CapitaGit.ui.info "-- Starting to check repository '#{repo.dir.to_s}' --------"
      CapitaGit.ui.confirm "-> Active user   : '#{repo.user_name} <#{repo.user_email}>'"
      CapitaGit.ui.confirm "-> User shortcut : '#{repo.user_shortcut}'"
      CapitaGit.ui.info '-----------------------------------------------------------'
      CapitaGit.ui.info ''

      CapitaGit.ui.info '-- Fetching changes from remote \'origin\' ------------------'
      repo.update_from_remote
      latest_major_release_tag = repo.latest_major_release_tag
      latest_minor_release_tag = repo.latest_minor_release_tag
      CapitaGit.ui.confirm "-> Latest major release tag is: #{latest_major_release_tag || '---'}"
      CapitaGit.ui.confirm "-> Latest minor release tag is: #{latest_minor_release_tag || '---'}"
      CapitaGit.ui.info '-----------------------------------------------------------'
      CapitaGit.ui.info ''

      if latest_major_release_tag.nil?
        CapitaGit.ui.warn 'No major release tag found, exiting!'
        exit 0
      end

      CapitaGit.ui.info '-- Checking for presence of major release fixbranch -------'
      local_fixbranch = repo.local_fixbranch_for_version?(latest_major_release_tag)
      remote_fixbranch = repo.remote_fixbranch_for_version?(latest_major_release_tag)
      CapitaGit.ui.confirm "-> Local  : #{local_fixbranch.nil? ? '---' : local_fixbranch.full }"
      CapitaGit.ui.confirm "-> Remote : #{remote_fixbranch.nil? ? '---' : remote_fixbranch.full }"

      if not repo.has_remote_fixbranch_for_version?(latest_major_release_tag)
        CapitaGit.ui.info "--> Creating remote fixbranch #{latest_major_release_tag}-fix"
        repo.create_remote_fixbranch_for_version(latest_major_release_tag)
      end

      if not repo.has_local_fixbranch_for_version?(latest_major_release_tag)
        CapitaGit.ui.info "--> Creating tracking local fixbranch #{latest_major_release_tag}-fix from remote fixbranch"
        repo.create_local_fixbranch_for_version(latest_major_release_tag)
      end

      CapitaGit.ui.info '-----------------------------------------------------------'
    end

    desc "create", "Creates a new feature branch with the given name and optional source branch"
    def create(name, source=nil)
      repo = CapitaGit::Repository.open(Dir.pwd)
      source = source.nil? ? repo.current_branch : source
      raise "Source branch '#{source}' does not exist" unless repo.has_local_branch?(source)
      raise "Source branch '#{source}' is a feature branch, can't branch from that!" if repo.is_local_feature_branch?(source)

      CapitaGit.ui.confirm "--> Creating and switching to feature branch '#{repo.user_shortcut}_#{source}_#{name}'"
      repo.create_local_branch_from_source("#{repo.user_shortcut}_#{source}_#{name}", source)
      repo.checkout_local_branch("#{repo.user_shortcut}_#{source}_#{name}")
    end

    desc "update", "Updates a feature branch your currently on or specified by name"
    def update(name=nil)
      repo = CapitaGit::Repository.open(Dir.pwd)
      name = name.nil? ? repo.current_branch : name
      raise "Source branch '#{name}' does not exist" unless repo.has_local_branch?(name)
      raise "Source branch '#{name}' is not a feature branch, can't update!" unless repo.is_local_feature_branch?(name)

      CapitaGit.ui.confirm "--> Updating feature branch '#{name}' from '#{repo.source_branch(name)}'"
      repo.rebase_local_branch(name)
    end

    desc "close", "Closes a feature branch your currently on or specified by name onto the source branch"
    def close(name=nil)
      repo = CapitaGit::Repository.open(Dir.pwd)
      name = name.nil? ? repo.current_branch : name
      raise "Source branch '#{name}' does not exist" unless repo.has_local_branch?(name)
      raise "Source branch '#{name}' is not a feature branch, can't close!" unless repo.is_local_feature_branch?(name)

      CapitaGit.ui.confirm "--> Closing feature branch '#{name}' onto '#{repo.source_branch(name)}'"
      repo.close_local_branch(name)
    end

    desc "runner", "Generates a Gemfile into the current working directory"
    def runner(command)
      repo = CapitaGit::Repository.open(Dir.pwd)
      puts repo.send("#{command}")
    end

    private

    def have_groff?
      !(`which groff` rescue '').empty?
    end
  end
end
