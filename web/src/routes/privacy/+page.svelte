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
		<strong>Effective:</strong> May 5, 2026 ·
		<strong>App:</strong> Open Feelings (iOS) ·
		<strong>Bundle ID:</strong> <code>dev.finklea.openfeelings</code> ·
		<strong>Developer:</strong> Taylor Finklea
	</p>

	<h2>The short version</h2>
	<p>
		Open Feelings is a private, on-device journaling tool for naming and logging emotions.
		Everything you write stays on your device and (if you allow it) in your own private iCloud
		database. We never see it. There is no server we control, no account, no analytics, no ads,
		no third-party SDKs.
	</p>

	<h2>What we don't collect</h2>
	<p>Open Feelings does not:</p>
	<ul>
		<li>Create accounts or require sign-in.</li>
		<li>
			Send your check-ins, notes, intensity values, timestamps, or any other content to any
			server we run. We don't run any servers.
		</li>
		<li>
			Use analytics, telemetry, crash reporters, advertising IDs, fingerprinting, or any other
			tracking.
		</li>
		<li>Embed third-party SDKs that could collect data.</li>
		<li>Share, sell, rent, or trade any user information.</li>
		<li>Read your contacts, calendars, photos, location, or microphone.</li>
	</ul>

	<h2>What stays on your device</h2>
	<p>
		When you save a check-in, the app stores it in a private SwiftData database scoped to this
		app. That database lives in the app sandbox on the device and (if you have iCloud Drive
		enabled for Open Feelings) in the <strong>private</strong> CloudKit database under your own
		Apple ID. Apple's CloudKit infrastructure transports it; we do not have access to it.
		Apple's privacy commitments for CloudKit private databases apply. See
		<a href="https://www.apple.com/legal/privacy/" rel="noreferrer">apple.com/legal/privacy</a>
		and <a href="https://support.apple.com/HT202303" rel="noreferrer">Apple's iCloud security overview</a>
		for Apple's terms.
	</p>

	<p>Each check-in includes:</p>
	<ul>
		<li>The emotion you picked (path through the wheel: core / secondary / specific).</li>
		<li>An optional 1–5 intensity value.</li>
		<li>An optional free-text note.</li>
		<li>The local timestamp of the entry.</li>
		<li>A flag indicating whether you also wrote it to Apple Health (see below).</li>
	</ul>

	<h2>Optional integrations (off by default)</h2>
	<p>
		Each integration below is <strong>off by default</strong> and requires explicit per-permission
		consent through the system prompts iOS provides. You can disable any of them at any time in
		Open Feelings → Settings or in iOS Settings.
	</p>

	<h3>App lock (Face ID / Touch ID / passcode)</h3>
	<p>
		If you turn on the app lock, Open Feelings asks iOS to verify your identity using the standard
		<code>LocalAuthentication</code> framework before showing your data. The biometric template never leaves your device; we don't see it.
	</p>

	<h3>Apple Health — State of Mind (write-only)</h3>
	<p>
		If you turn on Apple Health integration, Open Feelings writes each check-in as a momentary
		"State of Mind" sample to your Health database, mapping the emotion to a valence value and
		label. The app never reads anything back from Health. You control this in iOS Settings →
		Privacy &amp; Security → Health → Open Feelings.
	</p>

	<h3>Local reminders</h3>
	<p>
		If you turn on daily reminders, Open Feelings asks iOS to schedule a local notification at the
		time you choose. Notifications are scheduled by the system on your device; nothing is sent to
		any server.
	</p>

	<h2>Export and sharing — your choice</h2>
	<p>
		You can export your check-ins as CSV or JSON via the History screen's export menu. The export
		creates a file in a temporary location on your device and hands it to iOS's standard share
		sheet so <strong>you</strong> decide where it goes (Files, AirDrop, Mail, Notes, etc.). We don't
		transmit the export anywhere.
	</p>

	<h2>Children</h2>
	<p>
		Open Feelings is not directed at children under 13. We do not knowingly collect any
		information from anyone, including children, because we do not collect information at all.
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
		<a href="mailto:taylor.finklea@gmail.com">taylor.finklea@gmail.com</a>
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
