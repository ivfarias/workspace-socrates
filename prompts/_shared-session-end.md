## Shared Session-End Sequence

Before declaring work complete or stopping:

1. **Commit Changes**
   - Make sure all changes are staged: `git add .`
   - Run: `git commit -m "[DESCRIPTIVE MESSAGE]"` 
   - Message should explain what was implemented/fixed, not just "work done"
   - Commit frequently (logical units, not massive single commit)

2. **Update Progress**
   - Edit `progress.md`:
     - Mark task as complete or note where you stopped
     - List what was implemented
     - List any blockers or next steps
     - Leave clear notes for next session
   - Save and commit: `git add progress.md && git commit -m "update: progress log"`

3. **Clean Up**
   - Remove any temporary files created during session
   - Revert any debug code left behind
   - Verify no IDE temporary files were committed

4. **Verify Clean State**
   - `git status` should show: `On branch <name>, nothing to commit, working tree clean`
   - If not clean: stage and commit remaining changes
   - Never leave a session with uncommitted changes
