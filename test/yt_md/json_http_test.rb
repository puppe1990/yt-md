# frozen_string_literal: true

require_relative "../test_helper"

class JsonHttpTest < YtMdTest
  def http_for(response)
    starter = lambda do |_uri, &block|
      client = Object.new
      client.define_singleton_method(:request) { |_req| response }
      block.call(client)
    end
    YtMd::JsonHttp.new(starter: starter)
  end

  def ok_response(body)
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.instance_variable_set(:@body, body)
    response.instance_variable_set(:@read, true)
    response
  end

  def not_found_response(body)
    response = Net::HTTPNotFound.new("1.1", "404", "Not Found")
    response.instance_variable_set(:@body, body)
    response.instance_variable_set(:@read, true)
    response
  end

  def test_get_returns_success_body
    body = %({"ok":true})
    assert_equal body, http_for(ok_response(body)).get("https://example.test/player")
  end

  def test_post_returns_success_body
    body = %({"browseId":"UC"})
    assert_equal body, http_for(ok_response(body)).post("https://example.test/browse", json: { "x" => 1 })
  end

  def test_raises_argument_error_with_status_path_and_body
    error = assert_raises(ArgumentError) do
      http_for(not_found_response("nope")).get("https://example.test/missing")
    end
    assert_match(/HTTP 404/, error.message)
    assert_match(%r{/missing}, error.message)
    assert_match(/nope/, error.message)
  end
end
