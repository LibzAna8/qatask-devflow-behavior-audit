#!/bin/bash

set -e

mkdir -p ~/.claude/commands ~/.claude/agents ~/.claude/skills

cp commands/behavior-audit.md ~/.claude/commands/
cp agents/behavior-extractor.md ~/.claude/agents/
cp agents/coverage-mapper.md ~/.claude/agents/
cp agents/gap-synthesizer.md ~/.claude/agents/
cp -r skills/react-behavior-patterns ~/.claude/skills/
cp -r skills/test-quality-patterns ~/.claude/skills/

echo "✓ behavior-audit installed — open Claude Code in any React+TypeScript project and run /behavior-audit"
