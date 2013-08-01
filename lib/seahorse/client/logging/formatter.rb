# Copyright 2013 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"). You
# may not use this file except in compliance with the License. A copy of
# the License is located at
#
#     http://aws.amazon.com/apache2.0/
#
# or in the "license" file accompanying this file. This file is
# distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF
# ANY KIND, either express or implied. See the License for the specific
# language governing permissions and limitations under the License.

require 'pathname'

module Seahorse
  module Client
    module Logging

      # A log formatter receives a {Response} object and return
      # a log message as a string..  When you construct a {Formatter}, you provide
      # a pattern string with substitutions.
      #
      #     pattern = '[REQUEST :http_status_code] :operation :duration'
      #     formatter = Seahorse::Logging::Formatter.new(pattern)
      #     formatter.format(response)
      #     #=> '[REQUEST 200] get_bucket 0.0352'
      #
      # # Canned Formatters
      #
      # Instead of providing your own pattern, you can choose a canned log
      # formatter.
      #
      # * {Formatter.default}
      # * {Formatter.short}
      # * {Formatter.debug}
      # * {Formatter.colored}
      #
      # # Pattern Substitutions
      #
      # You can put any of these placeholders into you pattern.
      #
      #   * `:client_class` - The name of the client class.
      #
      #   * `:operation_name` - The name of the client request method.
      #
      #   * `:request_params` - The user provided request parameters. Long
      #     strings are truncated/summarized if they exceed the
      #     {#max_string_size}.  Other objects are inspected.
      #
      #   * `:total_time` - The total time in seconds spent on the
      #     request.  This includes client side time spent building
      #     the request and parsing the response.
      #
      #   * `:http_time` - The time in seconds spent waiting on the network.
      #     This starts once data is given to the send handler and stops
      #     once the complete response has been received.
      #
      #   * `:client_time` - The time spent in the client preparing the
      #     request and processing the response.  This is the difference
      #     of `:total_time` and `:http_time`.
      #
      #   * `:retry_count` - The number of times a client request was retried.
      #
      #   * `:http_request_uri` - The complete request URI, including
      #      the scheme, host, port, pathname and querystring, e.g.,
      #      `http://domain.com:1234/path/name?query=string`.
      #
      #   * `:http_request_endpoint` - The request endpoint.  This includes
      #      the scheme, host and port, but not the path.
      #
      #   * `:http_request_scheme` - This is replaced by `http` or `https`.
      #
      #   * `:http_request_host` - The host name of the http request
      #     endpoint (e.g. 's3.amazon.com').
      #
      #   * `:http_request_port` - The port number (e.g. '443' or '80').
      #
      #   * `:http_request_method` - The http request verb, e.g., `POST`,
      #     `PUT`, `GET`, etc.
      #
      #   * `:http_request_path` - The full path (pathname plus querystring)
      #     for the request, e.g., `/bucket_name/objects/key?versions`.
      #
      #   * `:http_request_pathname` - The full path not including the
      #     querystring.
      #
      #   * `:http_request_querystring` - The request querystring.
      #
      #   * `:http_request_headers` - The http request headers, inspected.
      #
      #   * `:http_request_body` - The http request payload.
      #
      #   * `:http_response_status_code` - The http response status
      #     code, e.g., `200`, `404`, `500`, etc.
      #
      #   * `:http_response_headers` - The http response headers, inspected.
      #
      #   * `:http_response_body` - The http response body contents.
      #
      #   * `:config:option` - A specific configuration option, inspected.
      #     Replace the trailing `option` of this placeholder with a desired
      #     value, e.g., `:config:region`.  If the given option is not
      #     a valid configuration option, then the placeholder will be
      #     left unmodified.
      #
      class Formatter

        # @param [String] pattern The log format pattern should be a string
        #   and may contain substitutions.
        #
        # @option options [Integer] :max_string_size (1000) When summarizing
        #   request parameters, strings longer than this value will be
        #   truncated.
        #
        def initialize(pattern, options = {})
          @pattern = pattern
          @max_string_size = options[:max_string_size] || 1000
        end

        # @return [String]
        attr_reader :pattern

        # @return [Integer]
        attr_reader :max_string_size

        # Given a {Response}, this will format a log message and return it
        #   as a string.
        # @param [Response] response
        # @return [String]
        def format(response)
          pattern.gsub(/:(\w+)/) {|sym| send("_#{sym[1..-1]}", response) }
        end

        # @api private
        def eql?(other)
          other.is_a?(self.class) and other.pattern == self.pattern
        end
        alias :== :eql?

        private

        def method_missing(method_name, *args)
          if method_name.to_s.chars.first == '_'
            ":#{method_name.to_s[1..-1]}"
          else
            super
          end
        end

        def _client_class(response)
          raise NotImplementedError
        end

        def _operation_name(response)
          response.context.operation_name
        end

        def _request_params(response)
          summarize_hash(response.context.params)
        end

        def _total_time(response)
          time = response.context[:started_at] - response.context[:completed_at]
          ("%.06f" % time).sub(/0+$/, '')
        end

        def _http_time(response)
          raise NotImplementedError
        end

        def _client_time(response)
          raise NotImplementedError
        end

        def _retry_count(response)
          raise NotImplementedError
        end

        def _http_request_uri(response)
          response.http_request.endpoint + response.http_request.path
        end

        def _http_request_endpoint(response)
          response.context.http_request.endpoint
        end

        def _http_request_scheme(response)
          response.context.http_request.endpoint.scheme
        end

        def _http_request_host(response)
          response.context.http_request.endpoint.host
        end

        def _http_request_port(response)
          response.context.http_request.endpoint.port.to_s
        end

        def _http_request_method(response)
          response.context.http_request.http_method
        end

        def _http_request_path(response)
          response.context.http_request.path
        end

        def _http_request_pathname(response)
          response.context.http_request.path.split('?', 2)[0]
        end

        def _http_request_querystring(response)
          response.context.http_request.path.split('?', 2)[1]
        end

        def _http_request_headers(response)
          response.http_request.headers.inspect
        end

        def _http_request_body(response)
          response.http_request.body.tap do |body|
            body.rewind
            body.read
          end
        end

        def _http_response_status_code(response)
          response.context.http_response.status_code.to_s
        end

        def _http_response_headers(response)
          response.context.http_response.headers.inspect
        end

        def _http_response_body(response)
          raise NotImplementedError
        end

        # @param [Hash] hash
        # @return [String]
        def summarize_hash hash
          hash.map do |key,v|
            "#{key.inspect}=>#{summarize_value(v)}"
          end.sort.join(",")
        end

        # @param [Object] value
        # @return [String]
        def summarize_value value
          case value
          when String   then summarize_string(value)
          when Hash     then '{' + summarize_hash(value) + '}'
          when Array    then summarize_array(value)
          when File     then summarize_file(value.path)
          when Pathname then summarize_file(value)
          else value.inspect
          end
        end

        # @param [String] str
        # @return [String]
        def summarize_string str
          max = max_string_size
          if str.size > max
            "#<String #{str[0...max].inspect} ... (#{str.size} bytes)>"
          else
            str.inspect
          end
        end

        # Given the path to a file on disk, this method returns a summarized
        # inspecton string that includes the file size.
        # @param [String] path
        # @return [String]
        def summarize_file path
          "#<File:#{path} (#{File.size(path)} bytes)>"
        end

        # @param [Array] array
        # @return [String]
        def summarize_array array
          "[" + array.map{|v| summarize_value(v) }.join(",") + "]"
        end

        class << self

          # The default log format.
          #
          # @example A sample of the default format.
          #
          #     [AWS SimpleEmailService 200 0.580066 0 retries] list_verified_email_addresses()
          #
          # @return [Formatter]
          #
          def default

            pattern = []
            pattern << "[AWS"
            pattern << ":service"
            pattern << ":http_response_status"
            pattern << ":duration"
            pattern << ":retry_count retries]"
            pattern << ":operation(:options)"
            pattern << ":error_class"
            pattern << ":error_message"

            Formatter.new(pattern.join(' ') + "\n")

          end

          # The short log format.  Similar to default, but it does not
          # inspect the request params or report on retries.
          #
          # @example A sample of the short format
          #
          #     [AWS SimpleEmailService 200 0.494532] list_verified_email_addresses
          #
          # @return [Formatter]
          #
          def short

            pattern = []
            pattern << "[AWS"
            pattern << ":service"
            pattern << ":http_response_status"
            pattern << ":duration]"
            pattern << ":operation"
            pattern << ":error_class"

            Formatter.new(pattern.join(' ') + "\n")

          end

          # A debug format that dumps most of the http request and response
          # data.
          #
          # @example A truncated sample of the debug format.
          #
          #   +-------------------------------------------------------------------------------
          #   | AWS us-east-1 SimpleEmailService list_verified_email_addresses 0.429189 0 retries
          #   +-------------------------------------------------------------------------------
          #   |   REQUEST
          #   +-------------------------------------------------------------------------------
          #   |    METHOD: POST
          #   |       URL: https://email.us-east-1.amazonaws.com::443:/
          #   |   HEADERS: {"content-type"=>"application/x-www-form-urlencoded" ...
          #   |      BODY: Action=ListVerifiedEmailAddresses&Timestamp= ...
          #   +-------------------------------------------------------------------------------
          #   |  RESPONSE
          #   +-------------------------------------------------------------------------------
          #   |    STATUS: 200
          #   |   HEADERS: {"x-amzn-requestid"=>["..."], ...
          #   |      BODY: <ListVerifiedEmailAddressesResponse ...
          #
          # @return [Formatter]
          #
          def debug

            sig_pattern = []
            sig_pattern << ':region'
            sig_pattern << ':service'
            sig_pattern << ':operation'
            sig_pattern << ':duration'
            sig_pattern << ':retry_count retries'

            uri_pattern = []
            uri_pattern << ':http_request_protocol'
            uri_pattern << '://'
            uri_pattern << ':http_request_host'
            uri_pattern << '::'
            uri_pattern << ':http_request_port'
            uri_pattern << ':'
            uri_pattern << ':http_request_uri'

            line = "+" + '-' * 79

            pattern = []
            pattern << line
            pattern << "| AWS #{sig_pattern.join(' ')}"
            pattern << line
            pattern << "|   REQUEST"
            pattern << line
            pattern << "|    METHOD: :http_request_method"
            pattern << "|       URL: #{uri_pattern.join}"
            pattern << "|   HEADERS: :http_request_headers"
            pattern << "|      BODY: :http_request_body"
            pattern << line
            pattern << "|  RESPONSE"
            pattern << line
            pattern << "|    STATUS: :http_response_status"
            pattern << "|   HEADERS: :http_response_headers"
            pattern << "|      BODY: :http_response_body"

            Formatter.new(pattern.join("\n") + "\n")

          end

          # The default log format with ANSI colors.
          #
          # @example A sample of the colored format (sans the ansi colors).
          #
          #     [AWS SimpleEmailService 200 0.580066 0 retries] list_verified_email_addresses()
          #
          # @return [Formatter]
          #
          def colored

            bold = "\x1b[1m"
            color = "\x1b[34m"
            reset = "\x1b[0m"

            pattern = []
            pattern << "#{bold}#{color}[AWS"
            pattern << ":service"
            pattern << ":http_response_status"
            pattern << ":duration"
            pattern << ":retry_count retries]#{reset}#{bold}"
            pattern << ":operation(:options)"
            pattern << ":error_class"
            pattern << ":error_message#{reset}"

            Formatter.new(pattern.join(' ') + "\n")

          end

        end

      end
    end
  end
end
