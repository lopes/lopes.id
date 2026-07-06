# Lantana: With a Little Help of My (Claude) Friend

audience: internal team of security practitioners (my team)
duration: 15 minutes
tlp: clear
event: internal and informal meeting on how we're using AI

---

It's a 15-min presentation on Lantana (https://github.com/lopes/lantana), a honeypot as code project I created.

It's internal for my team. Public is the whole BA. Expected around 50 people, online.

The frame is how I used AI to build lantana.

More context in this post: https://lopes.id/log/lantana-1-honeypot-as-code/ And this post: https://lopes.id/log/lantana-2-data-pipeline/

Here's what I'm thinking: 4 sections + references

- Motivation: why i decided to create lantana (see Lantana 1
- 84 Years Ago, in 2025: The pre-modern way of using AI (Lantana 1)
- With a Little Help of My (Claude) Friend: How I used Claude to speed up development, this must be the core (Lantana 2)
- Caveats and Takeaways: See below
- References: See below

Feel free to adjust names. Keep it concise, direct. Tone is informal. 

---

Some extra context for "with a little help...":

- image ./assets/claude-usage-statistics.webp has the statistics before and after onboarding claude. It'd be nice to have this image + summary of statistics.
- image assets/claude-enrichment-optimization.webp shows a case when I had an insight: during first phases of tests, enrichment was taking more than 6h to finish. Then I had that insight in the image. Claude implemented. Enrichment dropped to less than 5 minutes. an outstanding result, from an insight of mine and ~10 minutes of Claude working.
- image assets/claude-recovery-from-session.webp shows an issue: in one project I was using to experiment AI (not lantana this one -- so possibly this slide could belong to takeaway or be entirely dropped, need help here). I was still controlling development by asking Claude to code and review, but I was committing -- and this repo had no Git yet. After that, I started letting Claude commit, giving proper instructions on that, like phasing projects and committing with more clear and direct messages, as seen in my user's claude.md file.

---

Caveats and Takeaways

- Taking some moments to learn how to USE AI was a game-changer. I'd mention: Learn to configure the AI (CLAUDE.md files), know how to prompt (passing enough context), know to plan with AI in multiple rounds including interviews, know how to deal with context windows to avoid context saturation.
- See my personal, use-level CLAUDE.md at https://github.com/lopes/dotfiles/blob/master/.config/claude/CLAUDE.md
- Add up to 3 good insights from @~/Documents/obsidian/1 Efforts/AI literacy here as bullets.

---

References

See "~/Documents/obsidian/1 - Efforts/AI Literacy"

