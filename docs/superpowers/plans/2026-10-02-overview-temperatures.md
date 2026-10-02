# Overview temperatures

Approved layout: put HNAT before MT7988 status; keep PPE rows only. Add CPU (MT7988), Wi-Fi (BE14), disk temperature figures above CPU/memory/SFP rows. No synthetic values or extra in-page explanations.

Additional approved requirement: include each SFP module temperature alongside its link speed, read from the existing SFP status API. Missing or failed SFP reads show a temperature dash.

Approved launcher artwork: router/network day and night variants. Include Android adaptive/monochrome resources and iOS Any/Dark/Tinted RGB assets, retaining legacy icon sizes.

1. Independent router component: extend existing system metrics with sanitized temperature records. Read labelled CPU thermal zones and NVMe/drivetemp hwmon sensors. Reuse the one-minute BE14 driver sample and expire its temperature cache after 180 seconds. Preserve wireless history fields and cadence; no new daemon or dependency.
2. Phone: validate sensor kind and Celsius range, retain data on untouched sections, clear missing values after fresh reads. Show maximum available reading per category, with missing/stale values as a dash. Move HNAT before MT7988 status.
3. Verify package fixtures including malformed/stale/unsupported sensors and sampler history. Verify mobile API/model/widget handling, approved order, missing readings, format/analyze/full tests. Independently review changes.
4. Bump both versions, push package and phone repositories, verify CI dispatch and report device verification limits. Copy published package sources back to the root workspace mirror.
