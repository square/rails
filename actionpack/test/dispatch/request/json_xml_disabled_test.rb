require 'abstract_unit'

class JsonXmlDisabledTest < ActionController::IntegrationTest
  class TestController < ActionController::Base
    class << self
      attr_accessor :last_request_parameters
    end

    def parse
      self.class.last_request_parameters = request.request_parameters
      head :ok
    end
  end


  test "does not parse JSON by default" do
    assert_parses(
      {},
      "{\"person\": {\"name\": \"David\"}}", { 'CONTENT_TYPE' => 'application/json' }
    )
  end

  test "does not parse XML by default" do
    assert_parses(
      {},
      "{\"person\": {\"name\": \"David\"}}", { 'CONTENT_TYPE' => 'application/xml' }
    )
  end

  private
    def assert_parses(expected, actual, headers = {})
      with_test_routing do
        post "/parse", actual, headers
        assert_response :ok
        assert_equal(expected, TestController.last_request_parameters)
      end
    end

    def with_test_routing
      with_routing do |set|
        set.draw do |map|
          match ':action', :to => ::JsonXmlDisabledTest::TestController
        end
        yield
      end
    end
end
