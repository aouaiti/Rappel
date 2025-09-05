class RappelScheduler
  def self.process_due_rappels
    Rails.logger.info "Starting RappelScheduler at #{Time.now} - PID: #{Process.pid}"
    
    # Read plugin settings
    plugin_settings = Setting.plugin_rappel || {}
    overdue_only = plugin_settings['overdue_only'].to_s == '1'
    Rails.logger.info "RappelScheduler: overdue_only setting is #{overdue_only}"
    
    # Find rappels due to run
    begin
      due_rappels = Rappel.where('next_run_date <= ? OR next_run_date IS NULL', Time.now)
      Rails.logger.info "Found #{due_rappels.count} rappels due to run"
    rescue => e
      Rails.logger.error "Error retrieving due rappels: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      return
    end
    
    due_rappels.each do |rappel|
      begin
        Rails.logger.info "Processing rappel ##{rappel.id}: #{rappel.subject}"
        
        issue = rappel.issue
        if issue.nil?
          Rails.logger.info "Issue not found for rappel ##{rappel.id}"
          next
        end
        
        # If configured, only remind for overdue issues (past due date)
        if overdue_only
          due_date = issue.due_date
          if due_date.nil?
            Rails.logger.info "Skipping rappel ##{rappel.id} because issue has no due date and overdue_only is enabled"
            next
          end
          if due_date > Time.now
            Rails.logger.info "Skipping rappel ##{rappel.id} because issue due date (#{due_date}) is in the future and overdue_only is enabled"
            next
          end
        end
        
        # Enhanced check for closed/resolved issues
        # First check the built-in is_closed? method
        is_closed = issue.status.is_closed?
        
        # Then check for status names like "resolved", "rejected", etc. in various languages
        status_name = issue.status.name.downcase
        closed_keywords = ['resolved', 'rejected', 'closed', 'done', 'completed', 'fixed', 
                          'résolu', 'fermé', 'terminé', 'rejeté', 'clôturé', 'fini']
        
        is_closed ||= closed_keywords.any? { |keyword| status_name.include?(keyword) }
        
        if is_closed
          Rails.logger.info "Skipping rappel ##{rappel.id} because issue is closed/resolved (status: #{issue.status.name})"
          next
        end
        
        # Get all recipients
        recipients = []
        
        # Add assignee if there is one
        recipients << issue.assigned_to if issue.assigned_to
        
        # Add author of the issue
        recipients << issue.author if issue.author
        
        # Add watchers
        issue.watchers.each do |watcher|
          recipients << watcher.user
        end
        
        # Remove duplicates and ensure they are all Users with email
        recipients = recipients.uniq.select { |r| r.is_a?(User) && r.active? && r.mail.present? }
        Rails.logger.info "Recipients for rappel ##{rappel.id}: #{recipients.map(&:mail).join(', ')}"
        
        # Send email to each recipient
        if recipients.empty?
          Rails.logger.warn "No valid recipients found for rappel ##{rappel.id}"
        end
        
        success = true
        recipients.each do |recipient|
          begin
            Rails.logger.info "Sending email to #{recipient.mail} for rappel ##{rappel.id}"
            mail = RappelMailer.rappel_email(recipient, rappel)
            
            if mail
              mail.deliver_now
              Rails.logger.info "Email sent to #{recipient.mail}"
            else
              Rails.logger.error "Failed to create email for #{recipient.mail}"
              success = false
            end
          rescue => e
            Rails.logger.error "Error sending email to #{recipient.mail}: #{e.message}"
            Rails.logger.error e.backtrace.join("\n")
            success = false
          end
        end
        
        # Only update next run date if at least one email was sent successfully
        if success
          # Update next run date
          begin
            rappel.mark_as_sent
            Rails.logger.info "Updated next run date for rappel ##{rappel.id} to #{rappel.next_run_date}"
          rescue => e
            Rails.logger.error "Error updating next run date for rappel ##{rappel.id}: #{e.message}"
          end
        else
          Rails.logger.warn "Not updating next run date for rappel ##{rappel.id} due to email delivery failures"
        end
      rescue => e
        Rails.logger.error "Error processing rappel ##{rappel.id}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
      end
    end
    
    Rails.logger.info "RappelScheduler completed at #{Time.now} - PID: #{Process.pid}"
  end
end 