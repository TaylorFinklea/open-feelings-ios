<svelte:head>
	<title>Privacy Policy — Open Feelings</title>
	<meta
		name="description"
		content="Open Feelings does not collect, transmit, or share user data. Everything stays on your device or in your private iCloud database."
	/>
</svelte:head>

<a class="back-link" href="/">← Back to home</a>

<article class="policy">
	<h1>Privacy Policy</h1>

	<p class="meta">
		<strong>Effective:</strong> May 16, 2026 ·
		<strong>App:</strong> Open Feelings (iOS) ·
		<strong>Bundle ID:</strong> <code>dev.finklea.openfeelings</code> ·
		<strong>Developer:</strong> Taylor Finklea
	</p>

	<h2>The short version</h2>
	<p>
		Open Feelings is a private, on-device tool for naming and logging emotions. Everything you
		write stays on your device and, if you allow it, in your <strong>private</strong> iCloud
		database. We never see it. There is no server we control, no account, no analytics, no ads, and
		no third-party SDKs.
	</p>

	<h2>What we don't collect</h2>
	<p>Open Feelings does not:</p>
	<ul>
		<li>Create accounts or require sign-in.</li>
		<li>
			Send your check-ins, intentions, value sorts, committed actions, notes, intensity values,
			body regions, mood-scale values, timestamps, or any other content to any server we run. We
			don't run any servers.
		</li>
		<li>
			Use analytics, telemetry, crash reporters, advertising IDs, fingerprinting, or any other
			tracking.
		</li>
		<li>Embed third-party SDKs that could collect data.</li>
		<li>Share, sell, rent, or trade any user information.</li>
		<li>Read your contacts, calendars, photos, location, camera, or microphone.</li>
	</ul>

	<h2>What you enter, the app stores</h2>
	<p>Open Feelings handles only the data you choose to enter:</p>
	<ul>
		<li>
			<strong>Emotion check-ins</strong> — the feeling you pick from the wheel or wizard, optional
			intensity (1–5), optional body regions (curated or custom), optional body sensations, optional
			context, optional triggers and coping strategies, optional mood-scale values, and any
			free-text note.
		</li>
		<li>
			<strong>Daily intentions</strong> — the optional one-sentence intention you set each day, and
			the optional reflection you write afterward.
		</li>
		<li>
			<strong>Value sorts and committed actions</strong> — your bucketing of curated and custom
			values, your top-ranked list, and any committed actions you define (title, value reference,
			what's hard, reflection, completion).
		</li>
		<li>
			<strong>App preferences</strong> — check-in flow settings (picker style, body view mode,
			promoted steps), custom body regions and custom values you've added, reminder time, appearance
			mode, and Apple Health opt-in.
		</li>
	</ul>

	<h2>Where the data lives</h2>
	<ul>
		<li>
			<strong>On your device.</strong> A local SwiftData store in the app sandbox. The data never
			leaves the device unless you turn on iCloud sync (below) or explicitly tap a share affordance.
		</li>
		<li>
			<strong>In your private iCloud database.</strong> If you are signed in to iCloud and have
			iCloud Drive enabled for Open Feelings, Apple's CloudKit framework syncs your data between
			your own devices using the <em>private</em> database scoped to your Apple ID. The developer of
			Open Feelings has no access to that database. See
			<a href="https://www.apple.com/legal/privacy/" rel="noreferrer">apple.com/legal/privacy</a>
			and
			<a href="https://support.apple.com/HT202303" rel="noreferrer">Apple's iCloud security overview</a>.
		</li>
		<li>
			<strong>In Apple Health (optional).</strong> If you turn on Apple Health support, each saved
			check-in writes a momentary "State of Mind" sample to your Health database. Open Feelings
			never reads back from Health. You control this in iOS Settings → Privacy &amp; Security →
			Health → Open Feelings.
		</li>
	</ul>

	<h2>Apple Watch</h2>
	<p>
		If you install the paired Apple Watch app, watch-originated check-ins are delivered to your
		phone via Apple's WatchConnectivity framework and stored in the same on-device and (optional)
		private iCloud locations described above. The watch app makes no network requests.
	</p>

	<h2>Optional integrations (off by default)</h2>
	<p>
		Each integration below is <strong>off by default</strong> and requires explicit per-permission
		consent through the system prompts iOS provides. You can disable any of them at any time in
		Open Feelings → Settings or in iOS Settings.
	</p>

	<h3>Apple Health — State of Mind (write-only)</h3>
	<p>
		If you turn on Apple Health integration, Open Feelings writes each check-in as a momentary
		"State of Mind" sample to your Health database, mapping the emotion to a valence value and
		label. The app never reads anything back from Health.
	</p>

	<h3>Daily reminder notifications</h3>
	<p>
		If you turn on daily reminders, Open Feelings asks iOS to schedule a local notification at the
		time you choose. Notifications are scheduled by the system on your device; nothing is sent to
		any server.
	</p>

	<h2>Sharing you control</h2>
	<p>All sharing is initiated by you:</p>
	<ul>
		<li>
			<strong>History exports.</strong> From the History tab you can export check-ins as CSV, JSON,
			Markdown, or plain text. The file is created in a temporary location and handed to the iOS
			share sheet; you decide where it goes.
		</li>
		<li>
			<strong>Therapy summary PDF.</strong> From Settings → Sharing → Period summary for therapist,
			you can generate a PDF over a chosen window and detail level. The PDF stays on the device
			until you tap share.
		</li>
		<li>
			<strong>Apple Journal / Day One / Notes handoff.</strong> From any individual check-in you can
			send a Markdown summary to Apple Journal, Day One, Notes, or any other share-sheet target.
		</li>
	</ul>

	<h2>Children</h2>
	<p>
		Open Feelings is not directed at children under 13 and does not knowingly collect data from
		anyone — because we do not collect data at all.
	</p>

	<h2>Your rights and how to delete your data</h2>
	<ul>
		<li><strong>Delete the app</strong> from your device to remove the local database.</li>
		<li>
			<strong>Delete your iCloud copy</strong> by going to iOS Settings → [your name] → iCloud →
			See All → Open Feelings, or by deleting the app while signed in to iCloud.
		</li>
		<li>
			<strong>Revoke any optional integration</strong> at any time in Open Feelings → Settings or
			in iOS Settings.
		</li>
	</ul>
	<p>
		Because there is no server we control, there is no account or copy on our side to delete.
	</p>

	<h2>Changes to this policy</h2>
	<p>
		If we ever change what the app does in a way that changes this policy, we will update the
		effective date at the top and ship the new policy as part of an app update. The app does not
		phone home to fetch policy updates dynamically.
	</p>

	<h2>Contact</h2>
	<p>
		Questions, corrections, or concerns:
		<a href="mailto:taylor.finklea@gmail.com">taylor.finklea@gmail.com</a>, or file an issue at the
		<a href="https://github.com/TaylorFinklea/open-feelings-ios/issues" rel="noreferrer"
			>project's GitHub repository</a
		>.
	</p>
</article>

<style>
	.back-link {
		display: inline-block;
		margin-top: var(--space-sm);
		margin-bottom: var(--space-lg);
		font-size: 0.95rem;
		color: var(--text-muted);
		text-decoration: none;
	}

	.back-link:hover,
	.back-link:focus-visible {
		color: var(--accent);
	}

	.policy {
		max-width: 38em;
		margin: 0 auto;
	}

	.policy .meta {
		color: var(--text-muted);
		font-size: 0.95rem;
		padding: var(--space-md) 0 var(--space-lg);
		border-bottom: 1px solid var(--divider);
		margin-bottom: var(--space-xl);
		line-height: 1.8;
	}
</style>
