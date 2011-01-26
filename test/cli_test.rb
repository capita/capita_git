require 'test_helper'

class CliTest < Test::Unit::TestCase
  with_a_repo_setup do
    should("do something...") { assert true }
  end
end
