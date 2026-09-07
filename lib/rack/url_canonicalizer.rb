# frozen_string_literal: true

require 'rack'
require_relative 'url_canonicalizer/version'
require_relative 'url_canonicalizer/configuration'
require_relative 'url_canonicalizer/railtie'

module Rack
  class UrlCanonicalizer
    IPV4_REGEX = /\A\d{1,3}(?:\.\d{1,3}){3}\z/
    REDIRECT_BODIES = {
      301 => 'Moved Permanently',
      302 => 'Found',
      307 => 'Temporary Redirect',
      308 => 'Permanent Redirect'
    }.freeze

    class << self
      def configuration
        @configuration ||= Configuration.new
      end

      def configure
        yield(configuration)
      end

      def reset_configuration!
        @configuration = Configuration.new
      end
    end

    def initialize(app, options = {})
      @app = app
      @config = self.class.configuration.dup

      validate_options!(options)

      options.each do |key, value|
        @config.public_send("#{key}=", value) if @config.respond_to?("#{key}=")
      end
    end

    def call(env)
      req = Rack::Request.new(env)
      return @app.call(env) unless (req.get? || req.head?) && !xhr_request?(req, env)

      path = env['PATH_INFO'] || ''
      return @app.call(env) if excluded_path?(path)

      target_host, host_redirect = normalize_host(req.host || '')
      norm_path = normalize_path(path)
      query_params = req.GET.dup
      locale_redirect = locale_redirect?(query_params)

      return @app.call(env) unless host_redirect || path != norm_path || locale_redirect

      [
        @config.redirect_status,
        {
          'location' => redirect_url(req, target_host, norm_path, query_params),
          'content-type' => 'text/html',
          'cache-control' => @config.cache_control
        },
        [REDIRECT_BODIES.fetch(@config.redirect_status, 'Redirected')]
      ]
    end

    private

    def validate_options!(options)
      strip = options[:strip_www] || options['strip_www']
      enforce = options[:enforce_www] || options['enforce_www'] || options[:prefer_www] || options['prefer_www']

      raise ArgumentError, 'Conflicting options: cannot enable both :strip_www and :enforce_www' if strip && enforce
    end

    def xhr_request?(req, env)
      return true if req.respond_to?(:xhr?) && req.xhr?

      env['HTTP_X_REQUESTED_WITH'] == 'XMLHttpRequest'
    end

    def excluded_path?(path_info)
      return false if @config.exclude_paths.nil? || @config.exclude_paths.empty?

      @config.exclude_paths.any? { |prefix| path_info.start_with?(prefix) }
    end

    def excluded_host?(host)
      return false if @config.exclude_hosts.nil? || @config.exclude_hosts.empty?

      @config.exclude_hosts.any? do |pattern|
        case pattern
        when Regexp then pattern.match?(host)
        when Proc then pattern.call(host)
        else pattern.to_s.casecmp?(host)
        end
      end
    end

    def normalize_host(host)
      return [host, false] if excluded_host?(host)
      return [host.sub(/\Awww\./i, ''), true] if @config.strip_www && host.downcase.start_with?('www.')
      return ["www.#{host}", true] if @config.enforce_www && should_enforce_www?(host)

      [host, false]
    end

    def should_enforce_www?(host)
      return false if host.empty? ||
                      host.downcase.start_with?('www.') ||
                      host == 'localhost' ||
                      host.end_with?('.localhost', '.local', '.test')

      !host.match?(IPV4_REGEX) && !host.include?(':')
    end

    def normalize_path(path)
      path = path.gsub(%r{/{2,}}, '/') if @config.collapse_slashes
      path = path.chomp('/') if @config.strip_trailing_slash && path.length > 1 && path.end_with?('/')
      path
    end

    def locale_redirect?(query_params)
      key = @config.locale_param
      return false unless key && query_params.key?(key)

      allowed = @config.allowed_locales_list
      return false if allowed&.include?(query_params[key].to_s)

      query_params.delete(key)
      true
    end

    def redirect_url(req, host, path, query_params)
      port = [80, 443].include?(req.port) ? '' : ":#{req.port}"
      query = Rack::Utils.build_nested_query(query_params)
      url = "#{req.scheme}://#{host}#{port}#{path}"
      query.empty? ? url : "#{url}?#{query}"
    end
  end
end
