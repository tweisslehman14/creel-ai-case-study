# Static evaluator walkthrough

Publish this `docs` directory with GitHub Pages after the case-study folder is the repository root. Select **Deploy from a branch → main → /docs**, or deploy its contents as the Pages artifact. No build step, package installation, external assets, analytics, or backend is required.

Set `REPOSITORY_URL` in `demo.js` after publication; until then the page explicitly displays a repository link placeholder. No Loom link is invented.

Preview by opening `index.html` directly, or serve this directory with `python3 -m http.server 8080` and visit localhost:8080. The walkthrough has four selectable stages, a prepared note action, accept/reject sample fact controls, and a two-note search. Every record is synthetic. It never captures or uploads user data and does not run AI.

The hosted walkthrough is separate from the working native iPhone application and local desktop Python application. Do not describe this static page as a deployed AI processor.
