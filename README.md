# CloudFlare DDNS via CF Worker

This repository brings several improvement to [this project](https://github.com/dethos/worker-ddns).

## Feature

- Auto create DNS record when missing
- IPv6 support (rudimentry)
- Allow the record to be specified by the user
- Multiple user support with allowed subdomain matching, and HMAC authentication

## Usage

The worker script requires Node.JS and WebPack to function.

Before starting, you need to create a new API Token on your Cloudflare's profile page with permissions to edit the DNS records of one of your domains (Permission `Zone.DNS.Edit`).

### Worker

You need to create a JSON file for authentication and authorization with the format:

```json
[
    {
        "id": "<id for the token>",
        "token": "<any random long string>",
        "allowed": "<allowed subdomain>"
    }
]
```

The `allowed` parameter supports wildcard (as described in the [wildcard-match](https://www.npmjs.com/package/wildcard-match) package). The root domain should not be included in the parameter. Here's a working example:

```json
[
    {
        "id": "charlie",
        "token": "+xM1Uz56ZX7mpVaDJcX49w==",
        "allowed": "*.charlie.partner"
    }
]
```

which will allow updating all subdomains on `charlie.partner.whatever.root.domain`.

Next, you need to minify the JSON and Base64-encode it. Then you need to get the Zone ID for your site (a long hex string available in the "Overview" page in your site, at the right sidebar).

Use Wrangler to create a new worker and clone the project in, set `src/index.js` as the main file. Set those environment variables:

- `CF_API_TOKEN`: As described above, your CF API Token with `Zone.DNS.Edit` permission to the specified zone. Use `wrangler secret put` to set this variable!
- `ZONE_ID`: The hex Zone ID. You can put this in the `wrangler.toml`.
- `AUTH`: The Base64-encoded JSON string containing auth data. Use `wrangler secret put` to set this variable!

Then publish the worker.

### Agent

(TBD)
