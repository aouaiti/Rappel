Rails.logger.info "Loading Rappel ActiveJob configuration"

# Configure ActiveJob to use the async adapter if not already configured
unless Rails.application.config.active_job.queue_adapter
  Rails.application.config.active_job.queue_adapter = :async
  Rails.logger.info "Rappel: Set ActiveJob queue adapter to :async"
end 