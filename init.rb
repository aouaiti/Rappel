require 'redmine'
require File.expand_path('../lib/rappel_patches', __FILE__)

Rails.logger.info "Initializing Rappel plugin - PID: #{Process.pid}"

Redmine::Plugin.register :rappel do
  name 'Rappel Plugin'
  author 'Aouaiti Ahmed'
  description 'A plugin for sending periodic reminders about tasks until they are completed'
  version '0.1'
  
  # Global settings
  settings default: { 'overdue_only' => '0' }, partial: 'settings/rappel_settings'
  
  # Register as a project module
  project_module :rappel do
    permission :view_rappels, { rappels: [:index] }
    permission :manage_rappels, { rappels: [:index, :new, :create, :edit, :update, :destroy] }
  end
  
  # Add menu item
  menu :project_menu, 
       :rappels, 
       { controller: 'rappels', action: 'index' },
       caption: 'Rappels', 
       param: :project_id
end

# Ensure the scheduler runs in both foreground and daemon mode
Rails.configuration.after_initialize do
  begin
    Rails.logger.info "Rappel plugin: After initialize hook triggered - PID: #{Process.pid}"
    
    # Load the job class
    require File.expand_path('../app/jobs/process_rappels_job', __FILE__)
    
    # Force ActiveJob to use the Async adapter which works better in both modes
    Rails.logger.info "Rappel plugin: Current ActiveJob queue adapter: #{ActiveJob::Base.queue_adapter.class.name}"
    
    # Create a database record to track if we've already scheduled our job for this server instance
    if ActiveRecord::Base.connection.table_exists?('settings')
      server_instance_id = Process.pid.to_s + Time.now.to_i.to_s
      scheduling_key = 'plugin_rappel_job_scheduled'
      
      # Store our server instance ID in the settings table
      if Setting.plugin_rappel.nil?
        Setting.plugin_rappel = { 'server_instance_id' => server_instance_id }
      else
        current_settings = Setting.plugin_rappel
        
        # Check if job is already scheduled by this instance
        if current_settings['server_instance_id'] == server_instance_id
          Rails.logger.info "Rappel plugin: Job already scheduled by this instance"
        else
          # Schedule the initial job
          ProcessRappelsJob.set(wait: 1.minute).perform_later
          Rails.logger.info "Rappel plugin: Scheduled initial job"
          
          # Update the setting
          current_settings['server_instance_id'] = server_instance_id
          Setting.plugin_rappel = current_settings
        end
      end
    else
      # If settings table doesn't exist yet, just schedule the job
      ProcessRappelsJob.set(wait: 1.minute).perform_later
      Rails.logger.info "Rappel plugin: Scheduled initial job (settings table not available)"
    end
    
  rescue => e
    Rails.logger.error "Rappel plugin: Error in initialization: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end
end

# Apply plugin patches
Rails.configuration.to_prepare do
  # Ensure the necessary files are loaded
  begin
    require_dependency 'rappel_scheduler'
  rescue => e
    Rails.logger.error "Rappel: Error loading dependencies: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end
end 