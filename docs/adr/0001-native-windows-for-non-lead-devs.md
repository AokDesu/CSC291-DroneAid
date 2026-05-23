# Native Windows is the standard dev environment for non-lead devs

4 of 5 team members run Windows; only the lead (Aok) runs Linux. To avoid debugging "works on my machine" issues during a 12-day class project, we standardised the 4 Windows devs on **native Windows + Android Studio + Flutter SDK + Firebase CLI Windows binary**, rather than WSL2 or a hybrid setup. WSL2 was rejected because Android emulator GPU passthrough is unreliable and most devs would end up running AVD on the Windows side anyway, producing a hybrid mess; native Windows trades a duplicated PowerShell-equivalent setup section (`docs/setup-windows.md`) for one consistent path the whole team can follow.

## Consequences

- README setup section must be maintained in two flavours (Linux/macOS and Windows).
- `DRONE_AID_HANDLE` env var documented for both `~/.bashrc` (Linux) and Windows system env / PowerShell profile.
- Helper scripts in `scripts/` must stay portable Python; new bash-only scripts require a PowerShell equivalent.
- The `SessionEnd` Claude Code hook that copies session JSONL into `docs/agent-logs/<handle>/` must work on Windows paths (`%USERPROFILE%\.claude`) as well as Linux (`~/.claude`).
