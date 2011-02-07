require 'test_helper'

class CliTest < Test::Unit::TestCase
  with_a_repo_setup do
    in_dir 'local_checkout_1' do
      after('git pull') { should_have_tag '1.0' }

      should('respond to git-cmd #status') { assert_command_match 'gitc status', "nothing to commit" }
      should('respond to git-cmd #pull') { assert_command_match 'gitc pull', "Already up-to-date" }
      should('respond to git-cmd #push') { assert_command_match 'gitc push', "Everything up-to-date" }

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

              should_not_have_file 'fixfile', :in => 'local_checkout_1'

              context "after pull and checkout of 1.0-fix in checkout 1" do
                setup do
                  in_dir 'local_checkout_1' do
                    assert_command 'git checkout 1.0-fix'
                    assert_command 'git pull'
                  end
                end
                should_have_file 'fixfile', :in => 'local_checkout_1'
              end
            end

          end
        end
      end

      gitc 'create my_feature' do
        should "be on branch USER_master_my_feature" do
          user = CapitaGit::Repository.open('.').user_shortcut
          assert_equal "#{user}_master_my_feature", repo.current_branch
        end

        should_not_have_file 'awesome_feature', :in => 'local_checkout_1'

        should "break trying to create another feature branch from existing feature branch" do
          assert_command_fail 'gitc create new_feature'
        end

        # Propagating changes on source branch with gitc update
        context "after checkout 2 pushes file master_2_update on master" do
          setup do
            in_dir 'local_checkout_2' do
              assert_command 'echo "foo" > master_2_update'
              assert_command 'git add . && git commit -m "master 2 update" && git push'
            end
          end

          after 'git pull origin master' do
            should_not_have_file 'awesome_feature', :in => 'local_checkout_1'
          end

          context "after invoking 'gitc update'" do
            setup { assert_command("#{ShouldaMacros::BIN_PATH} update") }
            should_have_file 'master_2_update', :in => 'local_checkout_1'
          end

#          context "while having the same file changed in origin" do
#            setup do
#              in_dir 'local_checkout_1' do
#                assert_command 'echo "foo" > master_2_update'
#                assert_command 'git add . && git commit -m "master 2 update"'
#              end
#            end
#
#            should "crash on invoking 'gitc update'" do
#              assert_command_fail("#{ShouldaMacros::BIN_PATH} update")
#            end
#          end
        end

        # Committing a fix and closing branch
        context "after committing a file and gitc close" do
          setup do
            assert_command 'echo "foo" > awesome_feature'
            assert_command 'git add . && git commit -m "my feature"'
            assert_command("#{ShouldaMacros::BIN_PATH} close")
            assert_command 'git push'
          end

          should "be on branch master" do
            assert_equal 'master', repo.current_branch
          end

          should "have removed the feature branch" do
            assert !repo.branches.map(&:name).any? { |n| n =~ /feature/ }
          end

          should_have_file 'awesome_feature', :in => 'local_checkout_1'

          context "after git pull on local_checkout_2" do
            setup do
              in_dir 'local_checkout_2' do
                assert_command 'git pull'
              end
            end

            should_have_file 'awesome_feature', :in => 'local_checkout_2'
          end
        end

      end
    end
  end
end
