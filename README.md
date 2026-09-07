# Rack::UrlCanonicalizer

`rack-url-canonicalizer` is a lightweight, zero-dependency Rack middleware for Ruby applications (Rails, Sinatra, Hanami, Roda, or plain Rack).

It automatically canonicalizes incoming request URLs to prevent search engine **Duplicate Content** penalties by enforcing:
1. Stripping `www.` or enforcing `www.` sub-domain prefix.
2. Collapsing duplicate slashes (`//path//to` ➔ `/path/to`).
3. Stripping trailing slashes from paths (`/path/` ➔ `/path`).
4. Validating `locale` GET query parameters against an allowed list and stripping invalid locales.

---

## When Is This Gem Necessary?

Search engines (Google, Yandex, Bing) treat every unique URL string as a distinct page. Without strict URL normalization, subtle variations in request paths create **Duplicate Content**, which splits link authority (PageRank), degrades search rankings, and wastes crawl budget.

This gem is essential when:
- **Protecting SEO & Domain Authority**: You need to prevent index cannibalization caused by variations like `example.com/item` vs. `www.example.com/item`, `example.com/item/`, or `example.com//item`.
- **Enforcing Single Canonical URLs**: You want incoming traffic from user typos or legacy backlinks to be redirected with an HTTP 301 (Moved Permanently) status to a single canonical address before reaching your application logic.
- **Handling Multi-Locale Query Parameters**: Your app supports localization (e.g. `?locale=en`) and you want to sanitize or discard invalid/malformed locale parameters (e.g. `?locale=xyz`) that would otherwise generate infinite duplicate URL variants.
- **High-Performance Early Redirects**: You want URL normalization to happen at the lightweight Rack middleware layer—avoiding unnecessary Rails controller instantiations, routing checks, or database queries.
- **Simplified Deployment with Kamal & Modern Stacks**: Ideal for containerized setups deployed with **Kamal**, **Thruster**, or Docker, where configuring and maintaining separate Nginx/Caddy redirect rules or complex DNS edge layers adds unnecessary overhead. This gem handles canonicalization directly inside your application stack for fast, zero-config deployments.

---


## Installation

Add this line to your application's `Gemfile`:

```ruby
gem "rack-url-canonicalizer"
```

And then execute:

```bash
bundle install
```

---

## Configuration Options

| Option | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `strip_www` | `Boolean` | `true` | Removes `www.` prefix from host. Automatically set to `false` if `enforce_www` is enabled. |
| `enforce_www` | `Boolean` | `false` | Prepends `www.` to requests lacking it (aliased as `prefer_www`). Automatically skips localhost and IP addresses. |
| `collapse_slashes` | `Boolean` | `true` | Replaces multiple slashes `//` with `/`. |
| `strip_trailing_slash` | `Boolean` | `true` | Removes trailing slash from path (except root `/`). |
| `exclude_paths` | `Array<String>` | `[]` | Array of path prefixes to bypass (e.g. `%w[/api /assets]`). |
| `exclude_hosts` | `Array<String \| Regexp \| Proc>` | `[]` | Array of hosts or patterns to bypass from host redirection. |
| `locale_param` | `String` | `"locale"` | GET parameter key for locale. |
| `allowed_locales` | `Array<String> \| Proc` | `nil` | List of allowed locales or callable returning them. |
| `redirect_status` | `Integer` | `301` | HTTP status code for redirects. |
| `cache_control` | `String` | `"public, max-age=86400"` | `Cache-Control` header for redirect responses. |

---

## Usage

### Ruby on Rails

In `config/application.rb`:

```ruby
# Strip www (default):
config.middleware.use Rack::UrlCanonicalizer,
  strip_www: true,
  collapse_slashes: true,
  strip_trailing_slash: true,
  exclude_paths: %w[/api /assets /up],
  allowed_locales: -> { I18n.available_locales }

# Or enforce www (example.com -> www.example.com):
config.middleware.use Rack::UrlCanonicalizer,
  enforce_www: true,
  exclude_hosts: %w[api.example.com]
```

### Sinatra / Plain Rack

In `config.ru`:

```ruby
require "rack/url_canonicalizer"

use Rack::UrlCanonicalizer,
  enforce_www: true,
  exclude_paths: ["/api"]

run MyApp
```

### Global Configuration

Alternatively, set global defaults:

```ruby
Rack::UrlCanonicalizer.configure do |config|
  config.enforce_www = true
  config.collapse_slashes = true
  config.allowed_locales = %w[en ru es]
end

# In Rack stack:
use Rack::UrlCanonicalizer
```

---

## Development & Testing

Run tests with RSpec:

```bash
bundle exec rspec
```

---

## License

The gem is available as open source under the terms of the [MIT License](LICENSE.txt).
# rack-url-canonicalizer
