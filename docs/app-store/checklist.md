# Submitting to the App Store

What's left for the owner, in order. Everything to paste is in the files linked from each step.

**Deadlines:** submit by **Nov 10**, so a rejection still leaves time. Live by **Nov 13, 11:59 PM PT** for Buffer
Commit. Review usually takes a day or two.

## Before App Store Connect

1. **Check the newest `1.0` build on TestFlight.** Each merge to `main` uploads one.
2. **Retake the screenshots** after any change to what they show: `just store-screenshots`
   ([screenshots.md](screenshots.md)).
3. **Check the pages are live:** <https://southp.github.io/buffer-snap/privacy/> and
   <https://southp.github.io/buffer-snap/support/>.
4. **Make the demo Buffer account:** password sign-in, no two-factor, one organization, a plan with Ideas. Sign in to it
   once from the TestFlight build and dictate one idea from the control.
5. **Link the privacy policy from Buffer's app client** settings, if it isn't already.

## In App Store Connect

6. **App Information:** name, subtitle, category, privacy policy URL ([listing.md](listing.md)). The warning there
   records the risk the name carries.
7. **Age Rating** → Edit: [age-rating.md](age-rating.md). Expect 4+.
8. **Pricing and Availability:** Free, all countries or the ones you want.
9. **App Privacy:** [app-privacy.md](app-privacy.md), then **Publish**.
10. **The 1.0 version page:**
    - Screenshots: `6.3-inch/` and `6.9-inch/`, in file-name order.
    - Promotional text, description, keywords, support URL, marketing URL, copyright: [listing.md](listing.md).
    - **Build:** pick the newest `1.0` build. Export compliance is already answered
      ([export-compliance.md](export-compliance.md)).
    - **App Review Information:** sign-in, contact and notes: [app-review-notes.md](app-review-notes.md).
    - **Version release:** "Automatically release this version", so it goes live as soon as it's approved.
11. **Add for Review**, then **Submit to App Review**.

## After approval

12. Check it's live, and copy the public link (`https://apps.apple.com/app/id<app ID>`) into the Buffer Commit entry.
13. Raise `MARKETING_VERSION` in `project.yml` before the next merge: App Store Connect refuses more 1.0 builds once
    1.0 is approved ([47-version-1-0.md](../decisions/47-version-1-0.md)).

## If it's rejected

Read the reason in App Store Connect → **App Review**, fix, merge, and pick the new build. Answers to the usual
questions about the `audio` background mode and the demo account are in [app-review-notes.md](app-review-notes.md).
