## Shared Startup Sequence

Every coding session begins with these steps:

1. **Print Context**
   - `pwd` - verify correct directory
   - Show current date/time
   
2. **Read Progress**
   - Check `progress.md` (if exists) to understand context from previous session
   - Review any notes left by prior agent
   - Understand current status and blockers

3. **Load Feature List**
   - Check `feature_list.json` (if exists)
   - Review all features: which are pending, in-progress, complete
   - Refresh your understanding of scope

4. **Review Git Context**
   - `git log --oneline -10` - see recent commits
   - `git status` - understand current branch state
   - `git diff` - see what's changed since last commit

5. **Sanity Check**
   - Run appropriate test: `npm test`, `cargo test`, `pytest`, `go test ./...`
   - If tests fail: STOP. Fix tests first. Do not proceed with work.
   - If tests pass: Continue to Step 6

6. **Pick ONE Task**
   - Select exactly ONE task from `feature_list.json`
   - Do NOT try to do multiple tasks in one session
   - Do NOT expand scope beyond selected task
   - Start work on that single task only
