# ARINC Audio Message Latency Monitoring
### Background Context

Previously, from the moment a HTTP request was sent by Realtime Signs and received by ARINC's headend server, we had no visibility into timing metrics or validation of the content displayed or played in stations. We only received an acknowledgment that the headend server received our request. While this is still the case today, we were able to improve upon the lack of latency metrics.

Increasing reports of delayed audio announcements prompted us to work with ARINC to find a way to gather these metrics, giving us better visibility into the nature of this message latency issue and helping us track down the root cause.
### Solution

With ARINC's help, we implemented a system to fetch message logs from each SCU on a nightly basis. This system works in several parts:

1. ARINC's headend server aggregates logs from each SCU every night and stores them in a zip file. These files can be downloaded via an HTTP endpoint on the headend server (configured as `message_log_zip_url`).

2. A CRON job (see `lib/jobs/message_log_job.ex`) makes a nightly request to this endpoint to fetch the previous day's zip file, which is then stored in the data platform dev archive S3 bucket.

3. A second CRON job (see `lib/jobs/message_latency_report.ex`) fetches the logs from S3, calculates statistics, and stores the resulting report in the same S3 bucket. This job also runs nightly.

### Message Latency Report Details

Here are the statistics calculated from the logs:

1. 95th percentile – The highest playback delay (in seconds) that 95% of messages experienced after being received.

2. 99th percentile – The highest playback delay (in seconds) that 99% of messages experienced after being received.

3. Count – The number of messages logged for that day only.

4. Count (prefilter) – The total number of messages in the log file, including any leftover entries from the previous day (as we sometimes notice that logs from the day prior can be mixed in).

These metrics help the MBTA hold our vendor ARINC accountable to our agreed-upon SLAs.
### Additional Details

You can manually run either of the above CRON jobs using endpoints hosted by RTS. However, due to firewall restrictions, you may need to remote into one of the headend servers to do so.

The `/run_message_log_job` route can be used to fetch message logs for a specific date. This is helpful when the nightly job fails and data is missing.

The `/run_message_latency_report` route can be used to generate message latency reports for one or more days.

# Device Uptime Monitoring

While ARINC does have its own alerting system to notify when in-station hardware devices go offline, this data was not easily accessible to us. To improve upon this, we asked ARINC to set up scripts that periodically query the statuses of various device types and software, then POST this data to an HTTP endpoint we host at `/uptime`.

This endpoint calls a module that parses the request body and logs device statuses to Splunk. This allows us to set up our own alerting around offline devices, enabling us to respond proactively to hardware outages.

For details on how device uptime data is parsed and logged, see `lib/monitoring/uptime.ex`.
# Active Headend IP Monitoring

ARINC's system uses two headend servers—one acting as the "prod" server and the other as a "backup." Occasionally, we need to cut over from one to the other, whether for emergencies or routine maintenance.

Historically, this cutover required a manual config change and a restart of RTS. Since migrating RTS to be cloud-managed and with its config values less accessible, we needed a more efficient way to facilitate this cutover.

To automate this process, similar to what we do for device uptime monitoring, we asked ARINC to implement a script that queries the current "prod" headend IP from their database and sends it to our endpoint at `/update_active_headend_ip`. This endpoint checks whether the received IP differs from the one in the application config. If it does, it updates the config and writes the new value to a file in the `mbta-signs` S3 bucket (`headend.json`). This ensures the active headend IP persists across subsequent restarts. See `lib/monitoring/headend.ex` to understand how this update happens.

If ARINC's script stops working or breaks, we can also manually update the file in S3. RTS fetches this value from S3 every 10 seconds, so no redeployment is needed.
