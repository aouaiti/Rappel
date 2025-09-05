module RappelExtensions
  # This hook will be called when Rails starts
  class Hooks < Rails::Railtie
    config.after_initialize do
      # Make sure we only load in server mode, not during rake tasks
      if defined?(Rails::Server)
        Rails.logger.info "RappelExtensions: Initializing automatic job scheduler"
        
        # Configure ActiveJob to use the async adapter if not already configured
        unless Rails.application.config.active_job.queue_adapter
          Rails.application.config.active_job.queue_adapter = :async
        end
        
        # Load the job class with the correct path
        require_dependency File.expand_path('../../app/jobs/process_rappels_job', __FILE__)
        
        # Schedule the first job
        # Use a small delay to ensure Rails is fully loaded
        Rails.application.config.after_initialize do
          Rails.logger.info "RappelExtensions: Scheduling first job"
          ProcessRappelsJob.schedule
        end
        
        Rails.logger.info "RappelExtensions: Scheduler initialized"
      end
    end
  end
end 