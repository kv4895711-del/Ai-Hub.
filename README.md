# AI Hub

One chat app for many free AI models. It talks to a local **FreeLLMAPI** gateway
that runs inside **Termux** on the same phone, so you only open this app.

## What it can do

- Claude-style chat with streaming replies, markdown and code blocks
- Switch the AI model any time, even in the middle of a chat
- Send photos, files and videos (for models that can read them)
- Voice input (speech to text) and read-aloud
- Chat history saved on the phone
- Glass UI, animated aurora background, many color themes, custom colors
- Starts the gateway in Termux by itself

## One-time setup on the phone

1. Install **Termux** from F-Droid (not from the Play Store).
2. Install FreeLLMAPI in Termux and make sure `npm run dev` works inside `~/freellmapi`.
3. In Termux, open the file `~/.termux/termux.properties` and add this line:

   ```
   allow-external-apps = true
   ```

   (Create the folder and file if they do not exist.) Then close and reopen Termux.
4. Copy `tools/startgateway.sh` to your home folder in Termux and make it runnable:

   ```
   cp startgateway.sh ~/startgateway.sh
   chmod +x ~/startgateway.sh
   ```

5. Install the AI Hub APK.
6. In Android Settings, open the AI Hub app permissions and allow
   **"Run commands in Termux environment"**.
7. Open AI Hub, go to **Settings**, paste your FreeLLMAPI unified key
   (it starts with `freellmapi-`) and tap **Test connection**.

## Default gateway address

```
http://localhost:3001/v1
```

## Building the APK

The APK is built by GitHub Actions (`.github/workflows/build.yml`).
Push to `main`, open the **Actions** tab, and download the APK artifact.

## Notes

- Free models have rate limits. If a reply stops, wait a little and retry.
- Your key is stored in the phone's secure storage and is never written to logs.
- Not every model understands images or video. Pick a model with vision for that.
