# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Rack::UrlCanonicalizer do
  include Rack::Test::Methods

  let(:inner_app) do
    ->(_env) { [200, { 'content-type' => 'text/plain' }, ['OK']] }
  end

  let(:options) { {} }

  let(:app) do
    Rack::UrlCanonicalizer.new(inner_app, options)
  end

  describe 'normal requests' do
    it 'passes clean GET requests through to the app' do
      get 'http://example.com/path'
      expect(last_response.status).to eq(200)
      expect(last_response.body).to eq('OK')
    end

    it 'passes root URL GET requests through' do
      get 'http://example.com/'
      expect(last_response.status).to eq(200)
      expect(last_response.body).to eq('OK')
    end

    it 'ignores non-GET/HEAD requests' do
      post 'http://www.example.com/path//'
      expect(last_response.status).to eq(200)
      expect(last_response.body).to eq('OK')
    end

    it 'ignores XHR requests' do
      get 'http://www.example.com/path//', {}, { 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }
      expect(last_response.status).to eq(200)
      expect(last_response.body).to eq('OK')
    end
  end

  describe 'strip_www' do
    context 'when strip_www is true (default)' do
      it 'redirects www to non-www' do
        get 'http://www.example.com/path'
        expect(last_response.status).to eq(301)
        expect(last_response.headers['location']).to eq('http://example.com/path')
        expect(last_response.headers['cache-control']).to eq('public, max-age=86400')
      end
    end

    context 'when strip_www is false' do
      let(:options) { { strip_www: false } }

      it 'does not redirect www host' do
        get 'http://www.example.com/path'
        expect(last_response.status).to eq(200)
      end
    end
  end

  describe 'enforce_www' do
    context 'when enforce_www is true' do
      let(:options) { { enforce_www: true } }

      it 'redirects naked domain to www' do
        get 'http://example.com/path'
        expect(last_response.status).to eq(301)
        expect(last_response.headers['location']).to eq('http://www.example.com/path')
        expect(last_response.headers['cache-control']).to eq('public, max-age=86400')
      end

      it 'automatically disables strip_www and does not redirect www host' do
        get 'http://www.example.com/path'
        expect(last_response.status).to eq(200)
      end

      it 'preserves non-standard port' do
        get 'http://example.com:8080/path'
        expect(last_response.status).to eq(301)
        expect(last_response.headers['location']).to eq('http://www.example.com:8080/path')
      end

      it 'preserves query parameters' do
        get 'http://example.com/path?foo=bar&baz=qux'
        expect(last_response.status).to eq(301)
        expect(last_response.headers['location']).to eq('http://www.example.com/path?foo=bar&baz=qux')
      end

      it 'does not redirect host with case-insensitive www prefix' do
        get 'http://WWW.example.com/path'
        expect(last_response.status).to eq(200)
      end

      it 'does not redirect localhost or dev domains' do
        get 'http://localhost/path'
        expect(last_response.status).to eq(200)

        get 'http://sub.localhost:3000/path'
        expect(last_response.status).to eq(200)

        get 'http://app.local/path'
        expect(last_response.status).to eq(200)

        get 'http://app.test/path'
        expect(last_response.status).to eq(200)
      end

      it 'does not redirect IPv4 addresses' do
        get 'http://127.0.0.1/path'
        expect(last_response.status).to eq(200)

        get 'http://192.168.1.1:3000/path'
        expect(last_response.status).to eq(200)
      end

      it 'does not redirect IPv6 addresses' do
        get 'http://[::1]:3000/path'
        expect(last_response.status).to eq(200)
      end

      it 'ignores non-GET/HEAD requests' do
        post 'http://example.com/path'
        expect(last_response.status).to eq(200)
      end

      it 'ignores XHR requests' do
        get 'http://example.com/path', {}, { 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }
        expect(last_response.status).to eq(200)
      end
    end

    context 'when prefer_www alias is used' do
      let(:options) { { prefer_www: true } }

      it 'redirects naked domain to www' do
        get 'http://example.com/path'
        expect(last_response.status).to eq(301)
        expect(last_response.headers['location']).to eq('http://www.example.com/path')
      end
    end

    context 'when enforce_www is false (default)' do
      it 'does not redirect non-www host' do
        get 'http://example.com/path'
        expect(last_response.status).to eq(200)
      end
    end

    context 'when both strip_www and enforce_www are true' do
      it 'raises ArgumentError on initialization' do
        expect do
          Rack::UrlCanonicalizer.new(inner_app, strip_www: true, enforce_www: true)
        end.to raise_error(ArgumentError, /Conflicting options/)
      end

      it 'raises ArgumentError when prefer_www is used with strip_www' do
        expect do
          Rack::UrlCanonicalizer.new(inner_app, strip_www: true, prefer_www: true)
        end.to raise_error(ArgumentError, /Conflicting options/)
      end
    end

    context 'when both strip_www and enforce_www are false' do
      let(:options) { { strip_www: false, enforce_www: false } }

      it 'does not redirect www or non-www hosts' do
        get 'http://www.example.com/path'
        expect(last_response.status).to eq(200)

        get 'http://example.com/path'
        expect(last_response.status).to eq(200)
      end
    end
  end

  describe 'exclude_hosts' do
    let(:options) do
      {
        enforce_www: true,
        exclude_hosts: [
          'api.example.com',
          /\Ainternal\./,
          ->(host) { host.start_with?('skip.') }
        ]
      }
    end

    it 'bypasses enforce_www for excluded hosts matching string' do
      get 'http://api.example.com/path'
      expect(last_response.status).to eq(200)
    end

    it 'bypasses enforce_www for excluded hosts matching regexp' do
      get 'http://internal.example.com/path'
      expect(last_response.status).to eq(200)
    end

    it 'bypasses enforce_www for excluded hosts matching proc' do
      get 'http://skip.example.com/path'
      expect(last_response.status).to eq(200)
    end

    it 'still canonicalizes non-excluded hosts' do
      get 'http://example.com/path'
      expect(last_response.status).to eq(301)
      expect(last_response.headers['location']).to eq('http://www.example.com/path')
    end
  end

  describe 'collapse_slashes' do
    context 'when collapse_slashes is true (default)' do
      it 'collapses multiple consecutive slashes into a single slash' do
        get 'http://example.com/path//to///resource'
        expect(last_response.status).to eq(301)
        expect(last_response.headers['location']).to eq('http://example.com/path/to/resource')
      end
    end

    context 'when collapse_slashes is false' do
      let(:options) { { collapse_slashes: false, strip_trailing_slash: false } }

      it 'preserves consecutive slashes' do
        get 'http://example.com/path//to'
        expect(last_response.status).to eq(200)
      end
    end
  end

  describe 'strip_trailing_slash' do
    context 'when strip_trailing_slash is true (default)' do
      it 'removes trailing slash from non-root paths' do
        get 'http://example.com/path/'
        expect(last_response.status).to eq(301)
        expect(last_response.headers['location']).to eq('http://example.com/path')
      end

      it 'does not remove slash from root path' do
        get 'http://example.com/'
        expect(last_response.status).to eq(200)
      end
    end

    context 'when strip_trailing_slash is false' do
      let(:options) { { strip_trailing_slash: false } }

      it 'retains trailing slash' do
        get 'http://example.com/path/'
        expect(last_response.status).to eq(200)
      end
    end
  end

  describe 'exclude_paths' do
    let(:options) { { exclude_paths: ['/api', '/assets'] } }

    it 'bypasses middleware for excluded path prefixes' do
      get 'http://www.example.com/api/v1/users//path/'
      expect(last_response.status).to eq(200)

      get 'http://www.example.com/assets/logo.png'
      expect(last_response.status).to eq(200)
    end

    it 'applies canonicalization for non-excluded paths' do
      get 'http://www.example.com/products/'
      expect(last_response.status).to eq(301)
      expect(last_response.headers['location']).to eq('http://example.com/products')
    end
  end

  describe 'allowed_locales' do
    context 'with array of allowed locales' do
      let(:options) { { allowed_locales: %w[en ru] } }

      it 'allows valid locale query params' do
        get 'http://example.com/path?locale=en'
        expect(last_response.status).to eq(200)
      end

      it 'removes invalid locale query params and redirects' do
        get 'http://example.com/path?locale=fr&page=2'
        expect(last_response.status).to eq(301)
        expect(last_response.headers['location']).to eq('http://example.com/path?page=2')
      end
    end

    context 'with Proc for allowed locales' do
      let(:options) { { allowed_locales: -> { %w[en de] } } }

      it 'evaluates proc dynamically' do
        get 'http://example.com/path?locale=de'
        expect(last_response.status).to eq(200)

        get 'http://example.com/path?locale=ru'
        expect(last_response.status).to eq(301)
        expect(last_response.headers['location']).to eq('http://example.com/path')
      end
    end
  end

  describe 'custom redirect_status and cache_control' do
    let(:options) do
      {
        redirect_status: 308,
        cache_control: 'no-cache'
      }
    end

    it 'uses custom redirect status and cache control header' do
      get 'http://www.example.com/path'
      expect(last_response.status).to eq(308)
      expect(last_response.headers['cache-control']).to eq('no-cache')
    end
  end

  describe 'combined normalization' do
    context 'with strip_www (default)' do
      let(:options) { { allowed_locales: %w[en ru] } }

      it 'performs all canonicalizations in a single redirect' do
        get 'http://www.example.com/catalog//item/?locale=invalid&sort=asc'
        expect(last_response.status).to eq(301)
        expect(last_response.headers['location']).to eq('http://example.com/catalog/item?sort=asc')
      end
    end

    context 'with enforce_www' do
      let(:options) { { enforce_www: true, allowed_locales: %w[en ru] } }

      it 'performs www enforcement, path normalization, and locale stripping in a single redirect' do
        get 'http://example.com/catalog//item/?locale=invalid&sort=asc'
        expect(last_response.status).to eq(301)
        expect(last_response.headers['location']).to eq('http://www.example.com/catalog/item?sort=asc')
      end
    end
  end

  describe 'global configuration' do
    after do
      Rack::UrlCanonicalizer.reset_configuration!
    end

    it 'allows configuring enforce_www globally' do
      Rack::UrlCanonicalizer.configure do |config|
        config.enforce_www = true
      end

      get 'http://example.com/test'
      expect(last_response.status).to eq(301)
      expect(last_response.headers['location']).to eq('http://www.example.com/test')
    end
  end

  describe 'README documentation' do
    it 'has a valid VERSION constant' do
      expect(Rack::UrlCanonicalizer::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
    end
  end
end
