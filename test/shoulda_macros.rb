module ShouldaMacros
  TEMP_DIR = File.expand_path(File.join(File.dirname(__FILE__), '..', 'tmp'))
  
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
      Open4.popen4(cmd) { |stdin, stdout, stderr| 'nothing to do' }
      assert_equal 0, $?.exitstatus, "Expected exit status of 0!"
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
          in_dir 'origin' do
            assert_command 'git init --bare'
          end
          
          in_dir "local_checkout_1" do
            assert_command 'git init'
            assert_command "echo 'foo bar commit' > README"
            assert_command "git add . && git commit -m 'Initial commit'"
            assert_command "git remote add origin #{temp_dir('origin')}"
            assert_command 'git push origin master'
          end
          
          in_dir "local_checkout_2" do
            assert_command "git clone #{temp_dir('origin')}"
          end
        end
        
        yield
      end
    end
  end
end
