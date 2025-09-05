class ProcessRappelsJob < ApplicationJob
  queue_as :default
  
  # This job will be scheduled to run periodically
  def perform
    # Add extra logging for debugging
    Rails.logger.info "ProcessRappelsJob running at #{Time.now} - PID: #{Process.pid}"
    
    # Using the Settings API to track lock status which works in all modes
    begin
      # Get or initialize plugin settings
      settings = Setting.plugin_rappel || {}
      
      # Check if job is locked
      job_locked = settings['job_locked'] == 'true'
      lock_timestamp = settings['lock_timestamp'].to_i
      
      # If locked, check if the lock is stale (older than 10 minutes)
      if job_locked && (Time.now.to_i - lock_timestamp) < 600 # 10 minutes
        Rails.logger.info "ProcessRappelsJob skipping at #{Time.now} - another process is running"
        ensure_scheduled
        return
      end
      
      # Set the lock
      settings['job_locked'] = 'true'
      settings['lock_timestamp'] = Time.now.to_i.to_s
      Setting.plugin_rappel = settings
      
      Rails.logger.info "ProcessRappelsJob starting at #{Time.now} with lock"
      
      # Process due rappels
      RappelScheduler.process_due_rappels
    rescue => e
      Rails.logger.error "Error in ProcessRappelsJob: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    ensure
      # Release the lock
      begin
        settings = Setting.plugin_rappel || {}
        settings['job_locked'] = 'false'
        Setting.plugin_rappel = settings
        Rails.logger.info "ProcessRappelsJob released lock"
      rescue => e
        Rails.logger.error "Failed to release database lock: #{e.message}"
      end
    end
    
    # Always re-schedule before exiting
    ensure_scheduled
  end
  
  # Make sure we're scheduled to run again
  def ensure_scheduled
    # Re-schedule this job to run again in 1 minute
    if ActiveJob::Base.queue_adapter.is_a?(ActiveJob::QueueAdapters::AsyncAdapter)
      # For async adapter (daemon mode)
      ProcessRappelsJob.set(wait: 1.minute).perform_later
      Rails.logger.info "ProcessRappelsJob scheduled to run again in 1 minute - PID: #{Process.pid}"
    else
      # For inline/other adapters, try scheduling directly
      begin
        next_run = 1.minute.from_now
        ProcessRappelsJob.set(wait_until: next_run).perform_later
        Rails.logger.info "ProcessRappelsJob scheduled to run at #{next_run} - PID: #{Process.pid}"
      rescue => e
        Rails.logger.error "Error scheduling next job: #{e.message}"
        # Fallback to delay method
        ProcessRappelsJob.delay(run_at: 1.minute.from_now).perform_later
      end
    end
  end
  
  # This method will be called when the server starts
  def self.schedule
    Rails.logger.info "Initial scheduling of ProcessRappelsJob at #{Time.now} - PID: #{Process.pid}"
    # Cancel any existing jobs that might be queued
    ActiveJob::Base.queue_adapter.try(:enqueued_jobs)&.select { |job| 
      job[:job] == ProcessRappelsJob 
    }&.each { |job|
      ActiveJob::Base.queue_adapter.try(:remove_job, job)
    }
    
    # Schedule a new job
    ProcessRappelsJob.set(wait: 1.minute).perform_later
  end
end 