<script lang="ts">
	export let size: number = 240;
	export let titleText: string = 'Open Feelings icon';
	$: pixel = `${size}px`;
</script>

<!--
	Three concentric earth-tone rings on parchment, mirroring the iOS app icon
	(scripts/generate-app-icon.swift). Stroke colors are constant in light/dark
	to match the iOS rendering; only the parchment background flips.
-->
<svg
	role="img"
	aria-label={titleText}
	viewBox="0 0 1024 1024"
	xmlns="http://www.w3.org/2000/svg"
	style="width: {pixel}; height: {pixel}; max-width: 100%;"
>
	<title>{titleText}</title>
	<rect x="0" y="0" width="1024" height="1024" rx="180" fill="var(--bg)" />
	<circle cx="512" cy="512" r="480" fill="none" stroke="#93AABF" stroke-width="56" />
	<circle cx="512" cy="512" r="360" fill="none" stroke="#C46A55" stroke-width="56" />
	<circle cx="512" cy="512" r="240" fill="none" stroke="#D9A43A" stroke-width="56" />
	<circle cx="512" cy="512" r="96" fill="#8E4F2C" />
</svg>
