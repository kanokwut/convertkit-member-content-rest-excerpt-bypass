# Kit, formerly ConvertKit: Member Content paywall bypass through the REST API excerpt field

The Member Content feature restricts a post to subscribers of a Kit product. The REST API
restriction is applied only to `content.rendered` and never to `excerpt.rendered`. An
unauthenticated visitor can therefore read the full body of any restricted post, and harvest every
restricted post on the site in a single bulk request.

Affected: the WordPress plugin `convertkit`, 3.5.0 and below. **Fixed in 3.5.1**, released
2026-11-10. This proof of concept pins 3.4.9, the release it was written against.

Severity as published: 5.3, `CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:L/I:N/A:N`, CWE-200. Reported at 7.5
with `C:H`; the vendor published it at `C:L`, the two differing in that one metric.

- CVE-2026-125439
- [GHSA-mwjf-fm84-fg65](https://github.com/Kit/convertkit-wordpress/security/advisories/GHSA-mwjf-fm84-fg65)

## Requirements

- docker
- curl

Everything binds to 127.0.0.1 only.

## Run

```bash
cd repro
./setup.sh      # builds the lab, installs 3.4.9, creates a restricted post
./run_poc.sh    # the three unauthenticated requests
./teardown.sh   # removes the containers and the volume
```

`setup.sh` downloads the plugin straight from wordpress.org, so this repository ships no plugin
code.

## What the run shows

A restricted post whose stored body is 518 characters, carrying the marker `SECRET-TOKEN-7731` near
the start and `END-OF-PAID-BODY` as the final words.

| Step | Request | Result |
|---|---|---|
| 1 | `GET /wp/v2/posts/4` | `content.rendered` is 340 chars with no `END-OF-PAID-BODY`, so the paywall works |
| 2 | `GET /wp/v2/posts/4&excerpt_length=100000` | same response: `content.rendered` still 340 and truncated, `excerpt.rendered` 518 with both markers |
| 3 | `GET /wp/v2/posts&per_page=100&excerpt_length=100000&_fields=id,excerpt` | the same full body inside a bulk listing of every post |

Step 2 is the clearest proof. In one response the plugin restricts one field and serves the complete
paid article in another.

## Root cause

`maybe_restrict_rest_content()` in `includes/class-convertkit-output-restrict-content.php` rewrites
only `data['content']['rendered']`, at lines 803 and 826 in 3.4.9. The excerpt field of the same
response is never touched. The only excerpt guard in that class is `maybe_restrict_feed_excerpt()`,
hooked to the RSS filter `the_excerpt_rss`, which does not apply to the REST API.

WordPress 6.6 and later accept an `excerpt_length` parameter from unauthenticated callers, so the
excerpt can be stretched over the whole body.

A second, independent route exists. The filter opens with:

```php
if ( ! isset( $response->data['content']['rendered'] ) ) {
    return $response;
}
```

so a request that drops the content field, for example `_fields=id,excerpt`, makes the filter return
without restricting anything at all.

## Incomplete fix

Version 3.4.8 added Member Content restrictions for the REST API, feeds, archives and the WooCommerce
Store API. The REST part of that work missed the excerpt field. Version 3.4.9 does not change it:
`class-convertkit-output-restrict-content.php` is byte identical between 3.4.8 and 3.4.9, the 3.4.9
changelog has no Member Content entry, and the bypass reproduces on a clean 3.4.9 install.

## Fix

What was suggested in the report, and what 3.5.1 shipped, are the same thing: restrict
`data['excerpt']['rendered']` alongside `data['content']['rendered']`, and rebuild it from the
already restricted preview rather than from the full body. Capping `excerpt_length` alone is not
enough, because WordPress regenerates the excerpt from the post content whenever no manual excerpt
exists. The same reasoning applies to any other response field derived from post content.

3.5.1 also widened the restriction beyond what this report covered, to attachments, search results
and AJAX requests.

## Why the lab seeds an access token

`can_view_post()` returns true immediately when `has_access_and_refresh_token()` is false, so the
paywall only engages once a Kit account is connected, which is the normal state of any site using
Member Content. `setup.sh` stores a dummy access token and refresh token to reach that state. No Kit
account and no network call to Kit are needed.

## Files

- `REPRODUCTION.txt` is the step by step write up.
- `evidence-3.4.9.txt` is the raw request and response transcript.
- `repro/` builds the lab and runs the PoC.
