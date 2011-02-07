require 'thor'
require 'thor/actions'
require 'rubygems/config_file'

Gem.configuration

module CapitaGit
  class CLI < Thor
    include Thor::Actions

    ['checkout', 'push', 'pull', 'fetch', 'add', 'rm', 'status', 'diff', 'commit', 'rebase'].each do |cmd|
      class_eval do
        desc "#{cmd}", "Passes #{cmd} to git"
        define_method cmd.to_sym do |*args|
          log :warn, 'You called a git command from gitc, passing it along for now...'
          system "git #{cmd} #{args}"
        end
      end
    end

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
              gitc-check
              gitc-create
              gitc-update
              gitc-close
              gitc-backport
              gitc-install_autocomplete)

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

    def create(name, source_branch=nil)
      repo = CapitaGit::Repository.open(Dir.pwd)
      source_branch = source_branch.nil? ? repo.current_branch.to_s : source_branch
      new_branch = "#{repo.user_shortcut}_#{source_branch}_#{name}"
      log :confirm, "--> Creating and switching to feature branch '#{new_branch}'"
      repo.create_local_branch(new_branch, source_branch)
      repo.checkout_local_branch(new_branch)
    end

    desc "update", "Updates a feature branch your currently on or specified by name"

    def update(feature_branch=nil)
      repo = CapitaGit::Repository.open(Dir.pwd)
      feature_branch = feature_branch.nil? ? repo.current_branch : feature_branch
      raise "Source branch '#{feature_branch}' is not a feature branch, can't update!" unless repo.is_local_feature_branch?(feature_branch)

      log :confirm, "--> Updating feature branch '#{feature_branch}' from '#{repo.source_branch(feature_branch)}'"
      repo.rebase_local_branch(feature_branch)
    end

    desc "close", "Closes a feature branch your currently on or specified by name onto the source branch"

    def close(feature_branch=nil)
      repo = CapitaGit::Repository.open(Dir.pwd)
      feature_branch = feature_branch.nil? ? repo.current_branch : feature_branch

      log :confirm, "--> Closing feature branch '#{feature_branch}' onto '#{repo.source_branch(feature_branch)}'"
      repo.close_local_branch(feature_branch)
    end

    desc "backport", "Merges changes from a fixbranch into master"

    def backport(fix_branch=nil)
      repo = CapitaGit::Repository.open(Dir.pwd)
      fix_branch = fix_branch.nil? ? repo.current_branch : fix_branch

      log :confirm, "--> Backporting changes from '#{fix_branch}' into 'master'"
      repo.merge_fixbranch(fix_branch)
    end

    desc "install_autocomplete", "asd"

    def install_autocomplete
      root = File.expand_path("../../", __FILE__)
      system "cp #{root}/bash_completion.txt ~/.gitc_completion"
      system "if grep -q 'gitc_completion' ~/.bashrc; then echo 'Done'; else echo '. .gitc_completion' >> ~/.bashrc; . ~/.gitc_completion; fi"
    end

    desc "publish", "Published a local branch to origin"

    def publish(branch_name=nil)
      repo = CapitaGit::Repository.open(Dir.pwd)
      branch_name = branch_name.nil? ? repo.current_branch : branch_name

      log :confirm, "--> Publishing '#{branch_name}' to 'origin"
      repo.publish_branch(branch_name)
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
