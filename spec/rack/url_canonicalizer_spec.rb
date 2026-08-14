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
    let(:options) { { allowed_locales: %w[en ru] } }

    it 'performs all canonicalizations in a single redirect' do
      get 'http://www.example.com/catalog//item/?locale=invalid&sort=asc'
      expect(last_response.status).to eq(301)
      expect(last_response.headers['location']).to eq('http://example.com/catalog/item?sort=asc')
    end
  end

  describe 'README documentation' do
    it 'has a valid VERSION constant' do
      expect(Rack::UrlCanonicalizer::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
    end
  end
end
