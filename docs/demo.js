/* No APIs, storage, or uploads. */
const REPOSITORY_URL = "https://github.com/tweisslehman14/creel-ai-case-study";
const panels = ["capture", "transfer", "review", "recall"];
const labels = ["Capture", "Bring it home", "Review", "Recall"];
const contexts = [
  ["A note is enough.", "A photo, a quick recording, or a few words can stand on their own. Classify it later—or leave it as a memory."],
  ["A deliberate handoff.", "The phone does one job: retain the record. A versioned package brings originals and context to the desktop, without automatic sync."],
  ["Proposals, with receipts.", "AI can help structure useful details. Every proposal points back to its source; a person can accept or reject it without changing the original."],
  ["A searchable memory.", "Find the fly, the conditions, or the experience you described. These two prepared notes demonstrate the interaction, not AI search."]
];
let current = 0;
function showStep(index) {
  current = index;
  panels.forEach((id, i) => { document.getElementById(id).hidden = i !== index; });
  document.querySelectorAll(".step").forEach((button, i) => {
    button.classList.toggle("active", i === index);
    if (i === index) button.setAttribute("aria-current", "step"); else button.removeAttribute("aria-current");
  });
  const context = document.getElementById("context");
  context.querySelector("h3").textContent = contexts[index][0];
  context.querySelector("p").textContent = contexts[index][1];
  document.getElementById("step-count").textContent = `0${index + 1} / 04 — ${labels[index]}`;
  document.getElementById("next").textContent = index === 3 ? "Back to capture ↺" : `Next: ${labels[index + 1].toLowerCase()} →`;
}
document.querySelectorAll(".step").forEach(button => button.addEventListener("click", () => showStep(Number(button.dataset.step))));
document.getElementById("next").addEventListener("click", () => showStep((current + 1) % panels.length));
document.getElementById("sample-note").addEventListener("click", event => {
  document.getElementById("sample-added").hidden = false;
  event.currentTarget.textContent = "✓ Sample note added";
  event.currentTarget.disabled = true;
});
function review(accepted) {
  document.getElementById("fact-status").textContent = accepted ? "Accepted · sample" : "Rejected · sample";
  document.getElementById("review-response").textContent = accepted ? "Sample proposal accepted. The original note is unchanged." : "Sample proposal rejected. The original note is unchanged.";
}
document.getElementById("accept").addEventListener("click", () => review(true));
document.getElementById("reject").addEventListener("click", () => review(false));
document.getElementById("search").addEventListener("input", event => {
  const query = event.target.value.trim().toLowerCase();
  let count = 0;
  document.querySelectorAll(".search-result").forEach(result => {
    result.hidden = !result.dataset.text.includes(query);
    if (!result.hidden) count += 1;
  });
  document.getElementById("no-results").hidden = count !== 0;
});
if (/^https:\/\/github\.com\/[^/]+\/[^/]+\/?$/.test(REPOSITORY_URL)) {
  const link = document.getElementById("repo-link");
  link.href = REPOSITORY_URL; link.textContent = "View repository ↗";
  link.target = "_blank"; link.rel = "noopener noreferrer";
  document.getElementById("repository-details").textContent = "See the repository for run instructions, source code, research, and recorded validation.";
}
