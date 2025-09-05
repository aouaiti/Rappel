# Rappel (Redmine Reminder) Plugin

Rappel is a lightweight Redmine plugin that sends periodic reminder emails for issues until they are completed. It supports per-reminder frequency, automatic background processing, and a global option to only remind on overdue issues.

## Features

- Create reminders per issue with flexible frequency: minute, hour, day, week, month
- Sends emails to: issue assignee, author, and all watchers (deduplicated, active users only)
- Skips reminders for issues that are closed/resolved
- Background processing via ActiveJob with an internal lock
- Optional rake task for cron-based scheduling
- Global setting: Only remind for overdue issues (skip issues without due date or with due date in future)
- Project-level permissions and menu entry

## Requirements

- Redmine 5.x/6.x
- A working email configuration in Redmine

## Installation

1. Copy or clone this plugin into `plugins/rappel` under your Redmine directory.
2. Install dependencies and run plugin migrations:
```bash
cd /path/to/redmine
bundle install
bundle exec rake redmine:plugins:migrate RAILS_ENV=production
```
3. Restart Redmine (Passenger/Phusion, Puma, etc.).

## Configuration

### Permissions and Menu
- Project module: `rappel`
- Permissions:
  - `view_rappels`: view list of reminders
  - `manage_rappels`: create, edit, delete reminders
- Menu: A `Rappels` entry appears in each project having the module enabled.

Enable the module per project: Project Settings → Modules → check `Rappel`.

### Global Settings
Administration → Plugins → Rappel Plugin → Configure
- Only send reminders when the issue is overdue: when enabled, reminders are sent only if the issue has a due date in the past. Issues without a due date are skipped. When disabled, reminders follow their schedule regardless of due date.

## How Reminders Work
- Due reminders are selected by `next_run_date <= now OR next_run_date IS NULL`.
- For each due reminder, recipients are collected (assignee, author, watchers) and emails are sent via `RappelMailer`.
- If at least one email was sent successfully, the reminder schedules its `next_run_date` by adding its frequency interval and stores `last_run_date`.
- Closed/resolved issues are skipped automatically.

## Scheduling Options
Use one method (recommended: ActiveJob), not both.

### 1) ActiveJob (default, automatic)
The plugin schedules `ProcessRappelsJob` to run periodically (about every minute) after Rails initializes. It uses a lock stored in `Setting.plugin_rappel` to avoid concurrent executions.

Nothing to configure if your environment supports ActiveJob `:async` or your chosen adapter processes jobs.

### 2) Cron + Rake task (alternative)
If you prefer cron, disable background job processing and run the rake task:
```bash
cd /path/to/redmine
bundle exec rake rappel:send_rappels RAILS_ENV=production
```
Add to crontab to run every minute:
```cron
* * * * * cd /path/to/redmine && bundle exec rake rappel:send_rappels RAILS_ENV=production >/dev/null 2>&1
```
The rake task uses a file-based lock at `tmp/rappel_processing.lock` to prevent overlaps.

## Creating a Reminder
1. Go to a project → `Rappels` menu.
2. Click `New Rappel`.
3. Select the issue, set subject/message, choose frequency unit and value.
4. Save. The reminder will be processed on the next scheduler tick.

Subject placeholders supported:
- `{{issue}}` → issue subject
- `{{id}}` → issue ID
- `{{status}}` → issue status name

## Important Behavior
- Overdue-only setting: when enabled, issues without a due date or with a future due date are skipped.
- Issue is considered closed/resolved if its status is closed or matches common localized terms (e.g., resolved, résolu).
- Emails are only sent to active users with an email address.

## Troubleshooting
- No emails sent: verify Redmine email settings and that at least one recipient (assignee/author/watcher) is active with a valid email.
- Reminders not advancing: `RappelScheduler` updates `next_run_date` only when at least one email is delivered successfully.
- Duplicate sends: ensure only one scheduling mechanism is active (ActiveJob OR cron), not both.
- Job not running: check `log/production.log` for `ProcessRappelsJob` entries and confirm your ActiveJob adapter is processing jobs.

## Uninstall
```bash
cd /path/to/redmine
bundle exec rake redmine:plugins:migrate NAME=rappel VERSION=0 RAILS_ENV=production
```
Restart Redmine.

## License
MIT
