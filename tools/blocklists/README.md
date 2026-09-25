# Content blocker lists

`build_blocklists.py` downloads the filter lists below, converts the rules Safari content
blockers can express into WebKit content rule list JSON, and writes compressed copies plus
`blocklists-manifest.json` into `Zalla/Blocklists`. Only this generated data ships in the app.

```
python3 tools/blocklists/build_blocklists.py --validate
```

`--validate` compiles every output with the real WebKit content rule compiler through
WebKitGTK 6 (Debian: `python3-gi gir1.2-webkit-6.0`). Install `soupsieve` so cosmetic selectors
are syntax checked. `--cache DIR` keeps downloaded copies so a rebuild is reproducible.

| List | Used for | License used |
| --- | --- | --- |
| EasyPrivacy | Trackers (free) | CC BY-SA 3.0 (dual GPLv3 / CC BY-SA 3.0) |
| EasyList, host rules | Common ad networks (free) | CC BY-SA 3.0 (dual GPLv3 / CC BY-SA 3.0) |
| EasyList, other network rules | Full ad blocking (Zalla Unlock) | CC BY-SA 3.0 |
| EasyList, element hiding | Hide ad spaces (Zalla Unlock) | CC BY-SA 3.0 |
| EasyList Cookie List + Fanboy's Annoyance List | Cookie banners and annoyances (Zalla Unlock) | CC BY-SA 3.0 (headers say CC BY 3.0) |

Not used: Peter Lowe's list (no open license; commercial use needs permission), AdGuard filters
(GPLv3 only), DuckDuckGo Tracker Radar (CC BY-NC-SA, non-commercial).

After a rebuild, bump nothing by hand: each part's `version` is a hash of its JSON, so the app
recompiles only lists whose content changed. Credit changes go in `BlocklistCredits` in
`Zalla/ContentBlockingViews.swift`.
