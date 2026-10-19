# Custom AI instructions

Stacked after the existing Aperçu design PR. iOS: Menu → Paramètres → Instructions de l’IA. Android: Settings → AI instructions. Edit a short instruction, save it, or restore the default and save. Blank/overlong input is rejected without truncation; the UI limit is 400 characters. iOS additionally checks the model token budget and reports an actionable error if an instruction cannot fit.

Settings are local and survive relaunch. A conversation snapshots the setting at its first question and keeps it for follow-ups, regeneration and reopening. Changing the setting applies to the next photo conversation. Existing iOS archives with no instruction field keep the original default when continued; they do not inherit a later setting. No model retraining, new model download or cloud generation endpoint is introduced.

The native model's existing system-prompt parameter receives the snapshot. iOS context rebuilding accounts for instruction tokens and clears context if the instruction changes. Model instruction-following quality still needs validation on physical devices with representative photos and French/domain-specific instructions.

Android retains its current conversation scope; persistent photo history belongs to the existing iOS history work. Android now resolves public Melange SDK 1.11.0 because the old private package is unavailable with current build credentials; its native API build compatibility is checked, but device inference acceptance remains separate.
