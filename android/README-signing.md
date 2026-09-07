# Release signing

Every app on Google Play is signed. The signature is how Google knows an
update came from the same people who published version 1 — not the app name,
not the package name, the key.

Until now this app signed release builds with Flutter's **debug key**, which
is a throwaway key identical on every machine in the world. Play rejects it.
That is fixed: a release build now refuses to run without a real key rather
than quietly producing an artifact that cannot be published.

## Read this before creating the key

**Turn on Play App Signing.** It is the default for new apps and it is the
safe choice. Google holds the real signing key; you hold an *upload key* and
sign with that. If you ever lose the upload key, Google can reset it and you
carry on.

Without Play App Signing, the key below is the only one that exists — lose it
and **the app can never be updated again**. Not recovered, not appealed: a new
listing, a new URL, zero reviews, zero installs, and every existing user
stranded on the last version they installed.

The choice is made once, in the Play Console, when the app is first created.

## Create the upload key

Run this once. It asks for a password twice, then some optional details
(name, organisation, city) — those appear nowhere users can see, so answer
briefly or press Enter through them.

Keep the keystore **outside this repository**. `.gitignore` covers the usual
names, but a file that is not in the working tree cannot be committed by
accident at all.

```
keytool -genkey -v -keystore C:\keys\rni-customer-upload.jks -storetype PKCS12 -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

`-storetype PKCS12` is the modern standard; `keytool` prints a "proprietary
format" warning for the older JKS. Both work for Android, PKCS12 just does not
nag.

`-validity 10000` is about 27 years. Play requires a key valid past 2033, and
an expired key has the same consequence as a lost one.

`keytool` ships with the JDK. If it is not found, it is under
`C:\Program Files\Android\Android Studio\jbr\bin\`.

## Tell the build about it

Create `android/key.properties` — **not** `android/app/key.properties`:

```
storePassword=the password you just typed
keyPassword=the same password, unless you set a different one
keyAlias=upload
storeFile=C:\\keys\\rni-customer-upload.jks
```

On Windows, either double every backslash as above or use forward slashes.
A single backslash is an escape character here and the path will not resolve.

This file is gitignored. It holds the passwords in plain text — that is how
Gradle reads them, and it is why the file never leaves the machine.

## Build a release

```
flutter build appbundle --release
```

The output is `build/app/outputs/bundle/release/app-release.aab`. That is what
Play wants — an `.aab`, not an `.apk`. Use `flutter build apk --release` only
for sending someone a build to install directly.

## Back it up, properly

Three things must survive a lost laptop, and they must survive **together**:

1. the `.jks` file
2. the store password
3. the key password and the alias (`upload`)

Two copies, in different places, at least one offline. A password manager entry
with the file attached is the usual answer. Do not put the only copy in the
repository, in a chat, or in an email to yourself.

The client should hold a copy too. It is their app: if they ever change
developer, this key is what lets the new one ship an update instead of starting
a new listing.

## Verify a build is signed with the right key

```
keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab
```

Compare the SHA-256 fingerprint with the one Play shows under
**Release → Setup → App signing**. They must match, or Play will reject the
upload with a signature error.
