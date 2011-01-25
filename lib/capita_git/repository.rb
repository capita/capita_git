require 'git'

module CapitaGit
  class Repository
    def self.open(path)
      new(path)
    end

    def method_missing(m, *args)
      @repository.send m, *args
    end

    def initialize(path)
      @repository = Git.open path
    end

    def update_from_remote
      @repository.fetch(remote)
    end

    def current_branch
      @repository.branches.local.select { |b| b.full == @repository.lib.branch_current }[0]
    end

    def create_feature_branch(name)
      raise "Can't create feature branch from branch #{current_branch} since you already seem to be on one" if current_branch =~ /#{user_shortcut}/
      system "git checkout -b #{user_shortcut}/#{current_branch}/#{name}"
    end

    def create_local_branch_from_source(name, source, track=false)
      raise "Branch '#{name}' already exists!" if has_local_branch?(name)
      system "git branch #{track ? '--track' : ''} #{name} #{source}"
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

    def rebase_local_branch(name)
      raise "Can't update #{name} since it doesn't exist!" unless has_local_branch?(name)
      checkout_local_branch source_branch(name)
      system "git pull"
      checkout_local_branch name
      system "git rebase #{source_branch(name)}"
    end

    def close_local_branch(name)
      rebase_local_branch(name)
      system "git checkout #{source_branch(name)}"
      system "git merge #{name}"
      system "git branch -d #{name}"
    end

    def has_local_branch?(name)
      !@repository.branches.local.detect { |b| b.full =~ /#{name.gsub('/', '\/')}/ }.nil?
    end

    def is_local_feature_branch?(name)
      ! name.match(/^#{user_shortcut}/).nil?
    end

    def create_remote_fixbranch_for_version(version)
      create_local_branch_from_source("local_#{version}-fix", version)
      push_local_branch_to_remote('origin', "local_#{version}-fix", "#{version}-fix")
      delete_local_branch("local_#{version}-fix")
    end

    def create_local_fixbranch_for_version(version)
      create_local_branch_from_source("#{version}-fix", "origin/#{version}-fix", true)
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
      @repository.config('user.name')
    end

    def user_email
      @repository.config('user.email')
    end

    def user_shortcut
      user_name.downcase.split(/\s/).map { |n| n[0, 1] }.join
    end

    def source_branch(name)
      name.split('_')[1]
    end

    private

    def remote
      @repository.remotes.select { |r| r.name == 'origin' }[0]
    end

    def major_release_tags
      @repository.tags.map(&:name).select { |tag| tag =~ /^\d+\.\d+$/ }
    end

    def minor_release_tags
      @repository.tags.map(&:name).select { |tag| tag =~ /^\d+\.\d+\.\d+$/ }
    end
  end
end