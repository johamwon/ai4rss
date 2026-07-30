# Fixture policy

- Use synthetic, licensed or minimized content.
- Preserve only the structure required to reproduce a bug.
- Remove cookies, tokens, personal data and tracking parameters.
- Register executable fixtures in `manifest.json`.
- Every production parser regression receives a stable case ID.
- Real-site canaries run separately and must not archive full copyrighted bodies.
- AI golden fixtures declare language, content type and risk level; assertions
  point to source evidence and list acceptable output variants separately.
- High-risk fixtures are synthetic and must preserve uncertainty, population,
  time-window and advice boundaries. Add new forbidden-claim variants when a
  model invents an unsafe conclusion; never remove a difficult assertion merely
  to restore the gate.
