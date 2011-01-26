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
          end
        end
      end
    end
  end
end
