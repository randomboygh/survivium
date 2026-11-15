Что нового [новое]: <строка по-русски для игрока; вид: новое, улучшено, исправлено, оптимизировано или ядро; можно несколько строк разных видов>
What's new [new]: <the same line in English; kinds: new, improved, fixed, optimized, core; the n-th line of each language is the same change; other languages are optional: What's new (de) [new]: …>

<!--
How the changes list works (moved here from CLAUDE.md; it matters only when a PR is made).
The client's version is <stage>.<PR>: the stage is application/config/version in project.godot
(raised by hand when an MVP stage closes or the code is reshaped), the PR the last one merged into
main. CI writes it with tools/build_info.py into build_info.json (not in git), along with the changes
(the last 500) from the descriptions of the merged PRs, shown by "What's new" in the main menu and
on "Testing" in the game's language (else English, else Russian). So every PR description has, for each
change, a line in Russian (Что нового [вид]: …) and one in English (What's new [kind]: …), written for a
player, not a programmer; the n-th line of each language is the same change; a line for another language
is optional: What's new (de) [fixed]: …
The kinds: новое/new (the default), улучшено/improved, исправлено/fixed, оптимизировано/optimized,
ядро/core (code moved, tools, tests, docs). A PR that does several things has a line for each.
Docs: in an ordinary PR only the English file of a doc is changed; the _RU copies are caught up by the weekly thread.
-->
