# frozen_string_literal: true

module Rack
  class UrlCanonicalizer
    class Configuration
      attr_accessor :collapse_slashes,
                    :strip_trailing_slash,
                    :downcase_path,
                    :downcase_paths,
                    :downcase_exclude_paths,
                    :exclude_paths,
                    :exclude_hosts,
                    :locale_param,
                    :allowed_locales,
                    :redirect_status,
                    :cache_control
      attr_reader :strip_www, :enforce_www

      def initialize
        @strip_www = true
        @enforce_www = false
        @collapse_slashes = true
        @strip_trailing_slash = true
        @downcase_path = false
        @downcase_paths = nil
        @downcase_exclude_paths = []
        @exclude_paths = []
        @exclude_hosts = []
        @locale_param = 'locale'
        @allowed_locales = nil
        @redirect_status = 301
        @cache_control = 'public, max-age=86400'
      end

      def strip_www=(val)
        @strip_www = val
        @enforce_www = false if val
      end

      def enforce_www=(val)
        @enforce_www = val
        @strip_www = false if val
      end

      alias prefer_www enforce_www
      alias prefer_www= enforce_www=

      def allowed_locales_list
        return nil if allowed_locales.nil?

        locs = allowed_locales.respond_to?(:call) ? allowed_locales.call : allowed_locales
        Array(locs).map(&:to_s)
      end
    end
  end
end
