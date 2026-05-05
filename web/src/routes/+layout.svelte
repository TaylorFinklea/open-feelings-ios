<script lang="ts">
	import '../app.css';
	import IconRings from '$lib/IconRings.svelte';
</script>

<a class="skip-link" href="#main">Skip to main content</a>

<div class="page">
	<header class="site-header">
		<a class="brand" href="/" aria-label="Open Feelings — home">
			<IconRings size={36} titleText="Open Feelings logo" />
			<span class="brand-text">Open Feelings</span>
		</a>
	</header>

	<main id="main" class="container">
		<slot />
	</main>

	<footer class="site-footer container">
		<p class="footer-row">
			<a href="/privacy">Privacy</a>
			<span class="dot" aria-hidden="true">·</span>
			<a href="mailto:taylor.finklea@gmail.com">taylor.finklea@gmail.com</a>
		</p>
		<p class="footer-attribution">
			Emotion taxonomy adapted from
			<a href="https://openemotionwheel.com" rel="noreferrer">Open Emotion Wheel v1.1</a> by David
			Thorpe (CC BY-SA 4.0).
		</p>
		<p class="footer-copy">© 2026 Taylor Finklea</p>
	</footer>
</div>

<style>
	.page {
		min-height: 100dvh;
		display: flex;
		flex-direction: column;
	}

	.site-header {
		max-width: var(--max-width);
		width: 100%;
		margin: 0 auto;
		padding: var(--space-lg) var(--space-lg) 0;
	}

	.brand {
		display: inline-flex;
		align-items: center;
		gap: var(--space-sm);
		text-decoration: none;
		color: var(--text);
	}

	.brand-text {
		font-family: var(--font-serif);
		font-size: 1.25rem;
		letter-spacing: -0.01em;
	}

	main {
		flex: 1 0 auto;
		padding-top: var(--space-xl);
		padding-bottom: var(--space-xxxl);
	}

	.site-footer {
		border-top: 1px solid var(--divider);
		padding-top: var(--space-xl);
		padding-bottom: var(--space-xl);
		color: var(--text-muted);
		font-size: 0.92rem;
	}

	.footer-row {
		display: flex;
		flex-wrap: wrap;
		gap: var(--space-sm);
		align-items: center;
		margin-bottom: var(--space-sm);
	}

	.dot {
		color: var(--divider);
	}

	.footer-attribution,
	.footer-copy {
		margin: 0 0 var(--space-xs) 0;
	}
</style>
