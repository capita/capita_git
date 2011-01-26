require 'test_helper'

class CliTest < Test::Unit::TestCase
  with_a_repo_setup do
    in_dir 'local_checkout_1' do
      after('git pull') { should_have_tag '1.0' }

      gitc 'check' do
        should_have_branch '1.0-fix'

        in_dir 'local_checkout_2' do
          should_not_have_branch '1.0-fix'
          
          gitc 'check' do
            should_have_branch '1.0-fix'
            
            context "after creating a fix" do
              setup do
                assert_command 'git checkout 1.0-fix'
                assert_command 'echo "foo" > fixfile'
                assert_command 'git add . && git commit -m "fixfile" && git push'
              end
              
              should "not have fixfile in local_checkout_1" do
                assert_equal 0, Dir[File.join(temp_dir('local_checkout_1'), 'fixfile')].length
              end
              
              should "have fixfile in local_checkout_1 after pull and checkout of fixbranch" do
                Dir.chdir(temp_dir('local_checkout_1')) do
                  assert_command 'git checkout 1.0-fix'
                  assert_command 'git pull'
                end
                assert_equal 1, Dir[File.join(temp_dir('local_checkout_1'), 'fixfile')].length
              end
            end
            
          end
        end
      end
    end
  end
end
