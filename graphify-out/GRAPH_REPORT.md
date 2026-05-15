# Graph Report - CustomScripts  (2026-05-16)

## Corpus Check
- 56 files · ~33,997 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 181 nodes · 158 edges · 57 communities (54 shown, 3 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `63d4713d`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 6|Community 6]]
- [[_COMMUNITY_Community 7|Community 7]]
- [[_COMMUNITY_Community 8|Community 8]]
- [[_COMMUNITY_Community 9|Community 9]]
- [[_COMMUNITY_Community 10|Community 10]]

## God Nodes (most connected - your core abstractions)
1. `CustomScripts Arsenal` - 13 edges
2. `CustomScripts - Context` - 9 edges
3. `Read-MenuInput()` - 6 edges
4. `Enable-WindowsSudoMode()` - 6 edges
5. `Sync-Aliases()` - 6 edges
6. `Command Categories` - 6 edges
7. `Invoke-Tool()` - 5 edges
8. `Start-WirelessBootstrap()` - 4 edges
9. `Install-Dependencies()` - 4 edges
10. `Installation` - 4 edges

## Surprising Connections (you probably didn't know these)
- None detected - all connections are within the same source files.

## Communities (57 total, 3 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.09
Nodes (21): code:powershell (.\setup.ps1 -Install), code:powershell (. $PROFILE), code:powershell (.\setup.ps1 -Install), code:powershell (scrcpy), code:text (CustomScripts/), code:powershell (.\setup.ps1 -Install), Command meanings, CustomScripts Arsenal (+13 more)

### Community 1 - "Community 1"
Cohesion: 0.21
Nodes (12): Connect-AdbTcpEndpoint(), Get-AdbDevices(), Get-AudioSelection(), Get-ConnectionMode(), Get-ManualEndpoint(), Get-QueuedInput(), Invoke-Tool(), Parse-AdbDeviceLine() (+4 more)

### Community 2 - "Community 2"
Cohesion: 0.26
Nodes (12): Enable-WindowsSudoMode(), Get-ScriptAliases(), Get-ScriptList(), Get-WindowsSudoCommand(), Get-WindowsSudoConfig(), Initialize-ProfileFile(), Install-Dependencies(), New-CmdShims() (+4 more)

### Community 3 - "Community 3"
Cohesion: 0.2
Nodes (9): Architecture, Bundled Runtime Assets, Changelog, CustomScripts - Context, Dependencies (managed by `setup.ps1 -Deps`), Overview, Pinned Packages (excluded from winget upgrade), Scripts (+1 more)

### Community 5 - "Community 5"
Cohesion: 0.33
Nodes (6): Command Categories, Developer Utilities, Files and Storage, Network and Connectivity, System and Admin, Terminal and Productivity

### Community 6 - "Community 6"
Cohesion: 0.83
Nodes (3): Convert-ToPdf(), Invoke-ExportToPdf(), Show-Usage()

### Community 7 - "Community 7"
Cohesion: 1.0
Nodes (3): Invoke-Mkproj(), Show-Header(), Show-Help()

## Knowledge Gaps
- **27 isolated node(s):** `Overview`, `Architecture`, `Scripts`, `The "Linux in Windows" Dictionary`, `Dependencies (managed by `setup.ps1 -Deps`)` (+22 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **3 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `CustomScripts Arsenal` connect `Community 0` to `Community 5`?**
  _High betweenness centrality (0.020) - this node is a cross-community bridge._
- **Why does `Command Categories` connect `Community 5` to `Community 0`?**
  _High betweenness centrality (0.007) - this node is a cross-community bridge._
- **What connects `Overview`, `Architecture`, `Scripts` to the rest of the system?**
  _27 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.09 - nodes in this community are weakly interconnected._