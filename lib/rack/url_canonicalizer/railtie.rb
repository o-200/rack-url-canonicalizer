# frozen_string_literal: true

if defined?(Rails::Railtie)
  module Rack
    class UrlCanonicalizer
      class Railtie < ::Rails::Railtie
      end
    end
  end
end
