require 'git'

module CapitaGit
  class Repository
    attr_accessor :git_remote
    attr_reader :logger

    def self.open(path, cli=nil)
      new(path, cli)
    end

    def method_missing(m, *args)
      @repository.send m, *args
    end

    def initialize(path, cli)
      @logger = cli

      begin
        log 'Opening repository'
        @repository = Git.open path
      rescue => e
        raise CapitaGit::RepositoryError.new 'Can\'t access repository: ' + e.message
      end

      @git_remote = 'origin'
      raise CapitaGit::UncleanError.new "Pending changes found!" if has_changes?
    end

    def name
      dir.to_s.split(/\//).last
    end

    def fetch_remote_changes
      log 'Fetching remote changes'
      @repository.fetch(@git_remote)
    end

    def current_branch
      @repository.branches.local.select { |b| b.full == @repository.lib.branch_current }[0]
    end

    def has_changes?
      log 'Checking for pending changes'
      changes = `git status --short`
      !changes.empty?
    end

    def create_local_branch(new_branch, source_branch, track=false)
      raise "Branch '#{new_branch}' already exists!" if has_local_branch?(new_branch)
      raise "Current branch '#{source_branch}' can't be used as a source for branching!" unless on_branchable_branch?(source_branch)
      system "git branch #{track ? '--track' : ''} #{new_branch} #{source_branch}"
    end

    def push_local_branch_to_remote(remote, local_name, remote_name=nil)
      if remote_name.nil?
        system "git push #{remote} #{local_name}"
      else
        system "git push #{remote} #{local_name}:#{remote_name}"
      end
    end

    def delete_local_branch(name)
      system "git branch -d #{name}"
    end

    def checkout_local_branch(name)
      raise "Can't checkout #{name} since it doesn't exist!" unless has_local_branch?(name)
      @repository.branch(name).checkout
    end

    def rebase_local_branch(branch)
      raise "Can't update #{branch} since it doesn't exist!" unless has_local_branch?(branch)
      checkout_local_branch source_branch(branch)
      system "git pull"
      checkout_local_branch branch
      system "git rebase #{source_branch(branch)}"
      raise CapitaGit::UncleanError.new "Rebasing failed, please correct and issue 'git rebase --continue'" if has_changes?
    end

    def close_local_branch(branch)
      raise "Source branch '#{branch}' is not a feature branch, can't close!" unless is_local_feature_branch?(branch)
      rebase_local_branch(branch)
      checkout_local_branch source_branch(branch)
      system "git merge #{branch}"
      system "git branch -d #{branch}"
    end

    def merge_fixbranch(branch)
      raise "Source branch '#{branch}' is not a fix branch!" unless is_local_fixbranch?(branch)
      checkout_local_branch 'master'
      system "git merge -m 'Backporting changes of fix branch \'#{branch}\' into master' #{branch}"
    end

    def publish_branch(branch)
      raise "Can't publish '#{branch}' since it doesn't exist!" unless has_local_branch?(branch)
      raise "'#{remote_name(branch)}' already exists remotely!" if has_remote_branch?(remote_name(branch))
      push_local_branch_to_remote('origin', branch, remote_name(branch))
      create_local_branch(remote_name(branch), "origin/#{remote_name(branch)}", true)
      checkout_local_branch remote_name(branch)
      system "git branch -D #{branch}"
    end

    def has_local_branch?(name)
      !@repository.branches.local.detect { |b| b.full =~ /^#{name}.*/ }.nil?
    end

    def has_remote_branch?(name)
      !@repository.branches.remote.detect { |b| b.full =~ /^#{name}.*/ }.nil?
    end

    def is_local_feature_branch?(name)
      !name.match(/^#{user_shortcut}/).nil?
    end

    def is_local_fixbranch?(name)
      local_fixbranch_for_version?(latest_major_release_tag).to_s == name
    end

    def on_branchable_branch?(branch)
      branch == 'master' or not is_local_feature_branch?(branch)
    end

    def create_remote_fixbranch_for_version(version)
      create_local_branch("local_#{version}-fix", version)
      push_local_branch_to_remote('origin', "local_#{version}-fix", "#{version}-fix")
      delete_local_branch("local_#{version}-fix")
    end

    def create_local_fixbranch_for_version(version)
      create_local_branch("#{version}-fix", "origin/#{version}-fix", true)
    end

    def local_fixbranch_for_version?(version)
      branches = @repository.branches.local.select { |b| b.full =~ /^#{version}-fix$/ }
      branches.nil? ? branches : branches[0]
    end

    def remote_fixbranch_for_version?(version)
      branches = @repository.branches.remote.select { |b| b.full =~ /#{version}-fix$/ }
      branches.nil? ? branches : branches[0]
    end

    def has_local_fixbranch_for_version?(version)
      !local_fixbranch_for_version?(version).nil?
    end

    def has_remote_fixbranch_for_version?(version)
      !remote_fixbranch_for_version?(version).nil?
    end

    def current_branch
      @repository.lib.branch_current
    end


    def latest_major_release_tag
      major_release_tags.sort.last
    end

    def latest_minor_release_tag(major_release=nil)
      major_release.nil? ? minor_release_tags.sort.last : minor_release_tags.select { |tag| tag =~ /^#{major_release}\..*$/ }.sort.last
    end

    def user_name
      @user_name ||= `git config --get user.name`.strip.chomp
    end

    def user_email
      @user_email ||= `git config --get user.email`.strip.chomp
    end

    def user_shortcut
      user_name.downcase.split(/\s/).map { |n| n[0, 1] }.join
    end

    def source_branch(name)
      name.split('_')[1]
    end

    def remote_name(name)
      name.gsub(/#{user_shortcut}_/, '').gsub(/_/,'-')
    end

    private

    def log(message)
      @logger.send(:debug, "[DEBUG] #{message}") if @logger
    end


#    def remote
#      @repository.remotes.select { |r| r.name == 'origin' }[0]
#    end

    def major_release_tags
      @repository.tags.map(&:name).select { |tag| tag =~ /^\d+\.\d+$/ }
    end

    def minor_release_tags
      @repository.tags.map(&:name).select { |tag| tag =~ /^\d+\.\d+\.\d+$/ }
    end
  end
end