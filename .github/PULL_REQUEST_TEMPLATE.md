#### Summary of changes

**Asana Ticket:** [TICKET_NAME](TICKET_LINK)

[Please include a brief description of what was changed]

#### Reviewer Checklist

- [ ] Meets ticket's acceptance criteria
- [ ] Any new or changed functions have typespecs
- [ ] Tests were added for any new functionality (don't just rely on Codecov)
- [ ] If `signs.json` was changed, there is a follow-up PR to `signs_ui` to update its dependency on this project
- [ ] This branch was deployed to the staging environment and is currently running with no unexpected increase in warnings, and no errors or crashes (compare on Splunk: [staging](https://mbta.splunkcloud.com/en-US/app/search/search?q=search%20index%3Drealtime-signs-dev%20%22%5Berror%5D%22%20OR%20%22%5Bwarn%5D%22%20OR%20%22CRASH%22&display.page.search.mode=verbose&dispatch.sample_ratio=1&earliest=-4h%40m&latest=now&sid=1545840107.3874236) vs. [prod](https://mbta.splunkcloud.com/en-US/app/search/search?q=search%20index%3Drealtime-signs-prod%20%22%5Berror%5D%22%20OR%20%22%5Bwarn%5D%22%20OR%20%22CRASH%22&display.page.search.mode=verbose&dispatch.sample_ratio=1&earliest=-4h%40m&latest=now&sid=1545840137.3874305))
