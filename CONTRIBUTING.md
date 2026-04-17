# Contributing to MacBrightFace

## Development Setup

- macOS 15.2 or later
- Xcode 16.2 or later

Clone the repository and open the project:

```bash
git clone https://github.com/dashhuang/MacBrightFace.git
cd MacBrightFace
open MacBrightFace.xcodeproj
```

## Local Checks

Before opening a pull request, run at least the Release build check:

```bash
xcodebuild -project MacBrightFace.xcodeproj -scheme MacBrightFace -configuration Release -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

If you want a faster source-level check:

```bash
xcrun swiftc -typecheck MacBrightFace/*.swift
```

## Reporting Bugs

Please include:

- macOS version
- Mac model and chip
- Display setup
- Whether HDR was enabled
- Steps to reproduce
- Expected behavior
- Actual behavior
- Screenshots or crash logs when relevant

For display-related bugs, mention whether you were using:

- A built-in display
- Apple Studio Display
- Pro Display XDR
- Another external HDR monitor

## Pull Requests

Keep pull requests focused and easy to review.

- Explain the user-visible change
- Note any behavior changes around HDR, multi-display handling, or menu bar UI
- Include verification steps
- Mention unresolved risks or follow-up work
