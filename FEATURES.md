# e2Atlas feature overview

**English** · [Deutsch](FEATURES.de.md) · [Back to the project page](README.md)

These features are included in **1.0.0-final**. Compatibility depends on the receiver's OpenWebif, streaming services and installed plugins. See the [changelog](https://github.com/Schrotty74/e2Atlas/blob/main/CHANGELOG.md) for validation and known limitations.

## Live TV and multiview

- Browse bouquets, search channel names and display receiver-provided channel logos.
- Watch one channel or use two, three or four multiview pictures with one selected audio source.
- Swap a small picture with the main picture while retaining each player's audio settings.
- Save multiview layouts per receiver, including channels, selected audio source, volume and mute state. Restored streams start in stages.
- Use the controls below the video for playback actions. The fullscreen control is icon-only, with a native tooltip and accessibility label. All 111 app-defined buttons have localized German and English help, including state-aware text for mute and pause/resume.
- Control volume and mute, switch to video-only fullscreen and return with Escape or a double-click.
- Recover each live playback slot independently, with up to three retries and a cancel control.
- Set a sleep timer to stop playback while local recordings continue.
- Request Apple's VideoToolbox decoder when supported. The playback library can fall back to software decoding; hardware decoding and CPU impact have not been measured.

## Programme guide

- Scroll horizontally through seven calendar days, with a visible date and fixed channel names. Choose a two-, four- or six-hour viewing span.
- Jump to now, 20:15 or saved custom times.
- Search titles and descriptions across the loaded seven-day range for the selected bouquet. Open a result in the timeline or find other loaded broadcasts of the same title.
- Read programme descriptions and view current-programme progress in the details.
- Show reminder bells and planned or running recording indicators in guide cells, search results and details. Planned timer markers cover supported single recordings; recurring and special timer types are excluded.
- Reuse listings in memory and a local cache per receiver and app channel. Scrolling and zooming do not fetch EPG again.
- Configure listing updates in the guide or Settings → EPG: Off, a six-hour default or a custom interval from one minute to seven days, with a saved start date and time. Updates retain existing listings while loading and do not restart playback or reload channels.

## Now and Next

- Open a compact programme view with bouquet, favourites and channel search, showing the current and next programme with details and playback controls.
- Keep loaded programme data while switching views or bouquets, reusing the existing weekly EPG cache.
- Advance programmes automatically at their scheduled boundaries. If no next programme is available, load EPG data for that channel; on errors, keep the displayed data and apply a cooldown before another request.

## EPGRefresh on the receiver

- Configure a daily time window, one or all available bouquets and a dwell time in seconds per channel.
- Read and save the receiver's EPGRefresh settings from the guide or EPG settings.
- The receiver runs the schedule while e2Atlas is closed. A compatible installed EPGRefresh plugin and a correctly set receiver clock are required; the plugin may group channels on the same transponder.

## Recording timers and AutoTimer

- Schedule receiver recordings from programme details and list existing timers.
- Edit supported single recordings and delete them after confirmation. Unknown and special timer types remain read-only.
- Display receiver-reported conflicts and select another matching broadcast from loaded EPG to fill the timer editor. The receiver checks the replacement when it is saved; a time overlap alone does not prove a tuner conflict.
- Create, edit and delete supported AutoTimer rules: title substring, one channel or bouquet, optional start-time window, weekdays, recording margins and duplicate detection on the same channel.
- Preview title, channel/bouquet, weekday and time-window matches using EPG already loaded on the Mac.
- AutoTimer runs on the receiver and requires the plugin's periodic search to be enabled separately. Advanced rules and unsupported inherited defaults remain protected. Preview uses the Mac's time zone; plugin filters and duplicate handling can produce different final results.

## Receiver recordings and local recording

- Browse receiver-provided recording folders and storage locations; search titles and descriptions.
- Combine planned timers, receiver-reported running timers and recording files with All, Planned, Running and Library filters. Files are labelled Library because OpenWebif does not reliably identify completed recordings.
- Play receiver recordings with pause, seeking, volume and fullscreen controls. Save positions locally per receiver and choose Resume or Play from Beginning.
- Show reported free and total receiver disk capacity, with current-folder association when available. Missing capacity values are not estimated.
- Record the original receiver stream to a local `.ts` file from the main player or a multiview picture. Choose a folder and duration, use programme titles in filenames, stop in the app and reveal the file in Finder.
- Stop local recording when disk space runs low. Receiver timers and local stream recording are separate functions.

## Reminders and favourites

- Set reminders from programme details with 1, 5, 10, 15, 30 or 60 minutes of lead time; list and remove upcoming reminders.
- Use native local macOS notifications, including delivery with e2Atlas closed. Permission is requested when adding a reminder. Focus, notification permissions and the Mac being on affect delivery.
- Open the corresponding programme details from a notification, including when the app launches.
- Adjust reminders when fresh EPG identifies a shifted broadcast unambiguously. Uncertain matches remain unchanged; revised reminder times already in the past are removed.
- Add or remove favourites with the star beside a channel. Favourites are saved per receiver and shown independently of bouquet selection.

## Receivers, appearance and app controls

- Save up to three receivers. Credentials are optional where the receiver permits access; passwords are stored in the macOS Keychain.
- Enable or disable automatic connection at launch in Receiver settings. Temporary reachability failures receive bounded retries; manual refresh can reload metadata without stopping playback.
- View receiver-reported hardware and software information. Confirmed tuner assignments and streams without assignments are distinguished; total occupancy may remain unknown, including with FBC tuners.
- Switch between German and English in the Language menu or Appearance settings. Views switch immediately; native macOS menus follow after reopening.
- Choose System, Ocean, Ivory or Bronze themes with light and dark palettes. Follow macOS appearance or choose Light or Dark manually.
- Create custom JSON themes from the template in Appearance settings. See the [theme guide](https://github.com/Schrotty74/e2Atlas/blob/main/Documentation/Themes/README.md).
- Open the homepage and repository from About. Closing the main window quits the app, including when auxiliary windows are open.
- Keep Dev, Beta and Final settings, caches and Keychain services separate.
- Export settings to a JSON backup and preview its contents before importing. Backups can include receiver profiles (addresses and usernames), favourites, multiview layouts, general options, custom guide times and valid custom themes. They exclude passwords, reminders, playback positions, local recording files, folder permissions and EPG caches. Import keeps existing profiles and entries, replaces general settings and may require a password for a newly added receiver.
