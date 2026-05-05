<script lang="ts">
	import IconRings from '$lib/IconRings.svelte';
</script>

<svelte:head>
	<title>Open Feelings — A calm, private feelings tracker for iPhone</title>
	<meta
		name="description"
		content="Log emotions on a three-ring wheel with body somatic, daily intentions, mood scale, and write-only Apple Health sync. On-device and your private iCloud — no accounts, no analytics."
	/>
	<meta property="og:title" content="Open Feelings" />
	<meta
		property="og:description"
		content="A calm, private feelings tracker for iPhone."
	/>
	<meta property="og:image" content="https://openfeelings.finklea.dev/og-image.png" />
	<meta property="og:url" content="https://openfeelings.finklea.dev/" />
	<meta property="og:type" content="website" />
	<meta name="twitter:card" content="summary_large_image" />
	<meta name="twitter:title" content="Open Feelings" />
	<meta
		name="twitter:description"
		content="A calm, private feelings tracker for iPhone."
	/>
	<meta name="twitter:image" content="https://openfeelings.finklea.dev/og-image.png" />
</svelte:head>

<section class="hero">
	<div class="hero-icon">
		<IconRings size={200} titleText="Open Feelings app icon" />
	</div>
	<h1>Open Feelings</h1>
	<p class="tagline">A calm, private feelings tracker for iPhone.</p>
	<span class="status">Coming soon to the App Store</span>
</section>

<section class="intro">
	<p>
		Open Feelings helps you name what you're feeling using a complete three-ring emotion wheel.
		Mark sensations on a body map, set a daily intention, and track mood over time — all
		on-device, with optional sync through your own private iCloud.
	</p>
</section>

<section class="features" aria-label="Features">
	<article class="feature">
		<h3>Name what you feel.</h3>
		<p>
			Three-ring emotion wheel adapted from Open Emotion Wheel v1.1, with clinically informed
			definitions when you tap a feeling.
		</p>
	</article>

	<article class="feature">
		<h3>Mind and body.</h3>
		<p>
			Body somatic chips, daily intentions, mood scale, and a check-in flow that adapts to
			whether feelings or sensations come first for you.
		</p>
	</article>

	<article class="feature">
		<h3>Private by design.</h3>
		<p>
			Stored on your device and in your private iCloud database. No accounts, no analytics, no
			third-party SDKs.
		</p>
	</article>
</section>

<section class="privacy-callout">
	<h2>Private by default</h2>
	<p>
		There is no server we control. Everything you write stays on your device — and, if you allow
		it, in your own private iCloud database. We never see it. No accounts, no analytics, no ads,
		no third-party SDKs.
	</p>
	<p>
		<a href="/privacy" class="privacy-link">Read the full privacy policy →</a>
	</p>
</section>

<style>
	.hero {
		text-align: center;
		padding: var(--space-xxl) 0 var(--space-xl);
	}

	.hero-icon {
		display: flex;
		justify-content: center;
		margin-bottom: var(--space-lg);
	}

	.tagline {
		font-size: 1.2rem;
		color: var(--text-muted);
		max-width: 32em;
		margin: 0 auto var(--space-lg);
	}

	.status {
		display: inline-block;
		background: var(--accent-soft);
		color: var(--accent);
		padding: var(--space-xs) var(--space-md);
		border-radius: 999px;
		font-size: 0.9rem;
		font-weight: 600;
		letter-spacing: 0.02em;
	}

	.intro {
		max-width: 40em;
		margin: var(--space-xxl) auto 0;
		text-align: center;
		font-size: 1.1rem;
		color: var(--text);
	}

	.features {
		display: grid;
		grid-template-columns: 1fr;
		gap: var(--space-lg);
		margin: var(--space-xxxl) 0;
	}

	@media (min-width: 768px) {
		.features {
			grid-template-columns: repeat(3, 1fr);
		}
	}

	.feature {
		background: var(--surface-elev);
		border: 1px solid var(--divider);
		border-radius: var(--radius-card);
		padding: var(--space-xl);
	}

	.feature p {
		margin: 0;
		color: var(--text-muted);
	}

	.privacy-callout {
		margin-top: var(--space-xxxl);
		padding: var(--space-xl);
		background: var(--surface-elev);
		border-radius: var(--radius-sheet);
		border: 1px solid var(--divider);
	}

	.privacy-callout h2 {
		margin-top: 0;
	}

	.privacy-link {
		font-weight: 600;
	}
</style>
