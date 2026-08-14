# frozen_string_literal: true

require 'rack'
require_relative 'url_canonicalizer/version'
require_relative 'url_canonicalizer/configuration'
require_relative 'url_canonicalizer/railtie'

module Rack
  class UrlCanonicalizer
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

      options.each do |key, value|
        writer = "#{key}="
        @config.send(writer, value) if @config.respond_to?(writer)
      end
    end

    def call(env)
      req = Rack::Request.new(env)

      return @app.call(env) unless req.get? || req.head?
      return @app.call(env) if xhr_request?(req, env)

      path_info = env['PATH_INFO'] || ''

      return @app.call(env) if excluded_path?(path_info)

      host = req.host || ''
      host_redirect = @config.strip_www && host.start_with?('www.')
      target_host = host_redirect ? host.sub(/\Awww\./, '') : host

      raw_path = path_info
      normalized_path = raw_path.dup

      normalized_path.gsub!(%r{/{2,}}, '/') if @config.collapse_slashes

      if @config.strip_trailing_slash && normalized_path.length > 1 && normalized_path.end_with?('/')
        normalized_path.chomp!('/')
      end

      query_params = req.GET.dup
      locale_redirect = false
      locale_key = @config.locale_param

      if locale_key && query_params.key?(locale_key)
        allowed = @config.allowed_locales_list
        if allowed && !allowed.include?(query_params[locale_key].to_s)
          query_params.delete(locale_key)
          locale_redirect = true
        end
      end

      if host_redirect || raw_path != normalized_path || locale_redirect
        scheme = req.scheme
        port = req.port
        port_part = [80, 443].include?(port) ? '' : ":#{port}"

        new_query = Rack::Utils.build_nested_query(query_params)
        new_url = "#{scheme}://#{target_host}#{port_part}#{normalized_path}"
        new_url << "?#{new_query}" unless new_query.empty?

        return [
          @config.redirect_status,
          {
            'location' => new_url,
            'content-type' => 'text/html',
            'cache-control' => @config.cache_control
          },
          [redirect_body(@config.redirect_status)]
        ]
      end

      @app.call(env)
    end

    private

    def xhr_request?(req, env)
      return true if req.respond_to?(:xhr?) && req.xhr?

      env['HTTP_X_REQUESTED_WITH'] == 'XMLHttpRequest'
    end

    def excluded_path?(path_info)
      return false if @config.exclude_paths.nil? || @config.exclude_paths.empty?

      @config.exclude_paths.any? do |prefix|
        path_info.start_with?(prefix)
      end
    end

    def redirect_body(status)
      case status
      when 301 then 'Moved Permanently'
      when 302 then 'Found'
      when 307 then 'Temporary Redirect'
      when 308 then 'Permanent Redirect'
      else 'Redirected'
      end
    end
  end
end
