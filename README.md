# ArabPatch Admin — original design preview

This public repository serves **only the compiled front-end output of the original private Astro Admin preview**, not an independently recreated mockup. Private source: `xNaeem/alw-website`, preserved branch: `codex/laptop-handoff-20261122`, design branch: `design/posthog-luxury-preview-20261122`.

The incorrect standalone HTML preview has been removed. To publish the original for the first time, run this in Windows PowerShell (Git and Node.js are already installed on the laptop):

```powershell
cd "$HOME\Desktop"
git clone https://github.com/xNaeem/arabpatch-admin-preview.git ArabPatch-Admin-Pages
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\ArabPatch-Admin-Pages\publish-original.ps1"
```

The included publishing script clones the private **design branch** independently, runs the original Astro build with a GitHub Pages base path, copies **compiled output only** to the public Pages repo, and pushes `main`. It leaves the protected original and production Admin unchanged. It does not include credentials, server source or production APIs.

For later approved updates, rerun:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$HOME\Desktop\ArabPatch-Admin-Pages\publish-original.ps1"
```

The final URL is https://xnaeem.github.io/arabpatch-admin-preview/ .

Until the initial original build is uploaded, the URL may show 404. GitHub Pages is static, so real PostHog/Tawked backend endpoints, authenticated admin operations and real email sends cannot run there.
