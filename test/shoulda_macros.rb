module ShouldaMacros
  TEMP_DIR = File.expand_path('/tmp/capita_git_tmp')
  BIN_PATH = File.expand_path(File.join(File.dirname(__FILE__), '..', 'bin/gitc'))
  
  # Test method level helpers
  module InstanceMethods
    # Returns the path to the temporary directory, with the optional subdirectory
    # Creates the directory if it's missing
    def temp_dir(subdirectory = nil)
      path = ShouldaMacros::TEMP_DIR
      path = File.join(path, subdirectory) if subdirectory
      FileUtils.mkdir_p(path)
      path
    end

    # Switches current working directory to the temp_dir subdirectory of given
    # name for the given block, switching back after execution    
    def in_dir(name)
      Dir.chdir(temp_dir(name)) do
        yield
      end
    end
    
    # Runs the specified command and asserts it's exit status should be 0
    def assert_command(cmd)
      Open4.popen4(cmd) { |pid, stdin, stdout, stderr|  }
      #puts `#{cmd}`
      assert_equal 0, $?.exitstatus, "Expected exit status of 0 for command '#{cmd}'"
    end

    # Runs the specified command and asserts it's exit status should be 1
    def assert_command_fail(cmd)
      Open4.popen4(cmd) { |pid, stdin, stdout, stderr|  }
      #puts `#{cmd}`
      assert_equal 1, $?.exitstatus, "Expected exit status of 1 for command '#{cmd}'"
    end
    
    # Opens a Git ruby lib instance for current working dir and returns it
    def repo
      Git.open(Dir.getwd)
    end
  end

  # Context and should block helpers  
  module ClassMethods
    
    #
    # Creates a repository with a remote in temp_dir
    #
    def with_a_repo_setup
      context "With a basic repo setup" do
        setup do
          ENV["GIT_WORK_TREE"] = nil
          ENV['GIT_DIR'] = nil
          ENV['GIT_INDEX_FILE'] = nil
          
          in_dir 'origin' do
            assert_command 'git init --bare'
          end
          
          in_dir "initial_commit" do
            assert_command 'git init'
            assert_command "echo 'foo bar commit' > README"
            assert_command "git add . && git commit -m 'Initial commit'"
            assert_command "git remote add origin #{temp_dir('origin')}"
            assert_command 'git push origin master'
          end
          
          in_dir "local_checkout_1" do
            assert_command "git clone #{temp_dir('origin')} ."
            assert_command 'git push origin master'
            assert_command 'git pull origin master'
          end
          
          in_dir "local_checkout_2" do
            assert_command "git clone #{temp_dir('origin')} ."
            assert_command 'git tag -a 1.0 -m "First release"'
            assert_command 'git push --tags origin master'
            assert_command 'git pull origin master'
          end
        end
        
        yield
        
        # Make sure the temporary directory is purged after every run
        teardown do
          FileUtils.rm_rf(temp_dir)
        end
      end
    end
    
    def in_dir(name)
      context "in dir '#{name}'" do
        setup do
          @original_wd ||= {}
          @original_wd[name] = Dir.getwd
          Dir.chdir(temp_dir(name))
        end
        
        yield
        
        teardown do
          Dir.chdir(@original_wd[name]) if @original_wd
        end
      end
    end
    
    # Invokes the gitc binary with given arguments and yields after the setup
    def gitc(args)
      context "after invoking 'gitc #{args}'" do
        setup { assert_command("#{BIN_PATH} #{args}") }
        yield
      end
    end
    
    def after(command)
      context "after '#{command}'" do
        setup do
          assert_command command
        end
        yield
      end
    end
    
    def should_have_branch(name)
      should "have branch '#{name}'" do
        assert repo.branches.map(&:name).include?(name), "Found in #{Dir.getwd}: " + repo.branches.map(&:name).inspect
      end
    end
    
    def should_not_have_branch(name)
      should "NOT have branch '#{name}'" do
        assert !repo.branches.map(&:name).include?(name), "Found in #{Dir.getwd}: " + repo.branches.map(&:name).inspect
      end
    end
    
    def should_have_tag(name)
      should "have tag '#{name}'" do
        assert repo.tags.map(&:name).include?(name), repo.tags.map(&:name).inspect
      end
    end
    
    def should_not_have_tag(name)
      should "NOT have tag '#{name}'" do
        assert !repo.tags.map(&:name).include?(name), repo.tags.map(&:name).inspect
      end
    end
    
    def should_have_file(name, options)
      raise "Usage: should_have_file 'filename', :in => 'tempdirname' (or %w(dir1 dir2))" unless options[:in]
      [options[:in]].flatten.each do |dir|
        should "have file '#{name}' in #{dir}" do
          assert_equal 1, Dir[File.join(temp_dir(dir), name)].length
        end
      end
    end
    
    def should_not_have_file(name, options)
      raise "Usage: should_not_have_file 'filename', :in => 'tempdirname' (or %w(dir1 dir2))" unless options[:in]
      [options[:in]].flatten.each do |dir|
        should "not have file '#{name}' in #{dir}" do
          assert_equal 0, Dir[File.join(temp_dir(dir), name)].length
        end
      end
    end
  end
end
