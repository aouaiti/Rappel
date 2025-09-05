class Rappel < ActiveRecord::Base
  belongs_to :project
  belongs_to :issue, foreign_key: 'issue_id', class_name: 'Issue'
  
  validates :subject, presence: true
  validates :issue_id, presence: true
  validates :frequency_unit, presence: true, inclusion: { in: %w(minute hour day week month) }
  validates :frequency_value, presence: true, numericality: { greater_than: 0 }
  
  scope :active, -> { where("(next_run_date <= ? OR next_run_date IS NULL)", Time.now) }
  
  def should_send?
    next_run_date.nil? || next_run_date <= Time.now
  end
  
  def mark_as_sent
    interval = case frequency_unit
               when 'minute'
                 frequency_value.minutes
               when 'hour'
                 frequency_value.hours
               when 'day'
                 frequency_value.days
               when 'week'
                 frequency_value.weeks
               when 'month'
                 frequency_value.months
               else
                 1.day # Default to daily if frequency_unit is invalid
               end
               
    self.last_run_date = Time.now
    self.next_run_date = Time.now + interval
    save
  end
  
  def processed_title
    if subject.present?
      subject.gsub(/\{\{issue\}\}/, issue.subject)
             .gsub(/\{\{id\}\}/, issue.id.to_s)
             .gsub(/\{\{status\}\}/, issue.status.name)
    else
      "Reminder: #{issue.subject} (##{issue.id})"
    end
  end
end 