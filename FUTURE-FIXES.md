# Future Fixes

## Onebox Expansion

Currently, Discourse oneboxes (`<aside class="onebox" data-onebox-src="...">`) are rendered as a simple clickable URL. In the future, expand these to show a richer preview including:

- Title (from the `<h4>` or `<header>` inside the onebox)
- Description/excerpt
- Thumbnail image (if available)
- Source domain with favicon

Onebox types to handle: GitHub issues/PRs/repos, Wikipedia, Twitter/X, YouTube, generic URL previews.
