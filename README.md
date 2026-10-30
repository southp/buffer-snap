# buffer-snap
A minimal iOS app that let you capture any inspiration into Buffer Create on the go in one touch without having to unlock your phone.

## Context
Inspiration is naughty. They come when you are lifting weights in a gym, eating the worst tofu in a fine dining, walking alongside a street carrying stuff with only one finger free, or being tripped over in a hike and seeing the most beautiful flower you've ever seen. 

At least for me, it never comes when I sit still and have all the creation tools at hands. I wish I'd have a quick way to capture the idea, even in its roughest form. Ironically, my iPhone is the only thing that's always with me even when I was tripped over in a hike. That's why I'm exploring this idea.

## How it'd work
The goal is that every capture should just happen in the widget without ever having to unlock the phone.  

1. The main app provides the following, while all the captures happen in the widget.
   1. Authenticate the API access through a Buffer account.
   2. View what's being captured
   3. Manage what's being captured
      1. Resend
      2. Delete
      3. No edit
   4. There will be no sync to Buffer Create. That's not the purpose of this app.
   5. The app should keep an upper limit of how many items to be stored offline, and shuffle things off in a FIFO manner.
3. Snapper: a dialog providing 4 quick captures: pure text, voice recording, a photo, and a video.
   1. Pure text: just a free text field with a limitation, say 300 chars. (Q: how to submit? a submission button is easy, but I'd like to explore a more touch-free UX)
   2. Voice recording: Hold the microphone button to start recording -> release the button to stop.
   3. A photo: Hold the camera button -> show a small preview -> release the button to take the photo. (This will likely need a tech spike. I don't want to open up a fully-fledged camera app since that'd ruin the purpose)
   4. A video: Hold the recording button -> show a small preview and start recording -> release the button to stop. (The same to the above)
4. Submission to Buffer Create is an offline-first experience: After each capture, the app stores the item locally and run a background job to submit with exponential back-off retries. 


## Delivery plan
The goal is to publicly launch the v1 in the app store within the [Buffer Commit](https://buffer.com/api/commit) window, Oct. 28 ~ Nov. 13.

1. Scaffolding: The dev workflow is established, every component of the app is connected together, and the app is up and running on my iPhone through TestFlight or something. Nothing really work is fine — what's key here is the whole app flow can be run through even if everything is mocked and the architecture of the code base is settled. (~ Nov. 1)
2. MVP: Authentication works, capturing by pure text with a submission works, offline storage & submission job works. (~ Nov. 7)
3. v1: Capturing by photo works, start working on submission to the app store (~ Nov. 14)
4. v1.2, audio: Capturing by audio works. This is where a general mechanism of internal trimming/processing of multimedia files will be introduced, and is likely more complicated than I thought. (~ Nov. 21)
5. v1.3, video: Capturing by video works. It's likely the hardest part so hard to tell. 
   * No matter what, go feature-freeze on Nov. 25, update in the app store, and then submit my application to Buffer Commit no matter what on Nov. 28
