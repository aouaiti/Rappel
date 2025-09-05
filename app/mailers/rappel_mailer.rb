class RappelMailer < Mailer
  def rappel_email(user, rappel)
    Rails.logger.info "Preparing rappel email for user #{user.mail} about issue ##{rappel.issue_id} - PID: #{Process.pid}"
    
    @rappel = rappel
    @issue = rappel.issue
    @user = user
    
    # Ensure we have all required data
    if @issue.nil?
      Rails.logger.error "Cannot send rappel email: Issue ##{rappel.issue_id} not found"
      return nil
    end
    
    begin
      # Setting host_name is critical for URLs to work in background mode
      default_url_options[:host] = Setting.host_name
      # Ensure the protocol is set 
      default_url_options[:protocol] = Setting.protocol || 'http'
      
      # Log current URL settings for debugging
      Rails.logger.info "Rappel mailer using host: #{default_url_options[:host]}, protocol: #{default_url_options[:protocol]}"
      
      @issue_url = url_for(controller: 'issues', action: 'show', id: @issue.id, only_path: false)
      
      # Make sure we have a valid subject
      subject = if @rappel.subject.present?
                  @rappel.processed_title
                else
                  "Rappel: #{@issue.subject}"
                end
                
      # Send the mail
      mail(to: user.mail,
           subject: subject,
           template_path: 'rappel_mailer',
           template_name: 'rappel_email') do |format|
        format.html { render layout: 'mailer' }
        format.text { render layout: 'mailer' }
      end
      
      Rails.logger.info "Rappel email prepared successfully for user #{user.mail}"
    rescue => e
      Rails.logger.error "Error preparing rappel email: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      nil # Return nil on error so the scheduler knows the email failed
    end
  end
end 