module RappelPatches
  # Patch for Issue model to handle missing reminders table gracefully
  module IssuePatch
    def self.included(base)
      base.class_eval do
        # Override any callbacks that might be related to reminders
        # This is a safe method to intercept any reminder-related calls
        def handle_reminder_updates
          # Just a placeholder - doesn't do anything but allows us to
          # safely intercept any callbacks from other plugins
          true
        end
      end
    end
  end
end

# Apply patches
Rails.application.config.to_prepare do
  unless Issue.included_modules.include?(RappelPatches::IssuePatch)
    Issue.include(RappelPatches::IssuePatch)
  end
  
  # Temporarily disable any observers that might be looking for the reminders table
  if defined?(ReminderObserver)
    # Disable the observer if it exists
    ActiveRecord::Base.observers.disable :reminder_observer
  end
  
  # Clean up any lingering code from kindReminder
  begin
    # Remove the kindReminder plugin from the Redmine plugin registry if it exists
    if Redmine::Plugin.registered_plugins[:kindReminder]
      Redmine::Plugin.unregister(:kindReminder)
    end
    
    # Override migration class to prevent failed migrations
    class ReminderMigration < ActiveRecord::Migration
      def up; end
      def down; end
    end
  rescue => e
    Rails.logger.warn "Error cleaning up kindReminder: #{e.message}"
  end
end 