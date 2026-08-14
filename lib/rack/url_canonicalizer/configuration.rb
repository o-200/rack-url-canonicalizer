# frozen_string_literal: true

module Rack
  class UrlCanonicalizer
    class Configuration
      attr_accessor :strip_www,
                    :collapse_slashes,
                    :strip_trailing_slash,
                    :exclude_paths,
                    :locale_param,
                    :allowed_locales,
                    :redirect_status,
                    :cache_control

      def initialize
        @strip_www = true
        @collapse_slashes = true
        @strip_trailing_slash = true
        @exclude_paths = []
        @locale_param = "locale"
        @allowed_locales = nil
        @redirect_status = 301
        @cache_control = "public, max-age=86400"
      end

      def allowed_locales_list
        return nil if allowed_locales.nil?

        locs = allowed_locales.respond_to?(:call) ? allowed_locales.call : allowed_locales
        Array(locs).map(&:to_s)
      end
    end
  end
end
