require "test_helper"

class PingControllerTest < ActionDispatch::IntegrationTest
  # test "the truth" do
  #   assert true
  # end

  test "ping" do
    get ping_url

    assert_equal "OK", @response.body
  end
end
