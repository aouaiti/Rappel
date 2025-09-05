namespace :rappel do
  desc 'Send rappels for tasks according to configured frequencies'
  task :send_rappels => :environment do
    # This loads our scheduler model
    require File.expand_path('../../../app/models/rappel_scheduler', __FILE__)
    
    puts "Starting rappel:send_rappels task at #{Time.now}"
    
    # Using a file-based lock to prevent multiple processes from sending emails
    lock_file = File.join(Rails.root, 'tmp', 'rappel_processing.lock')
    
    # Skip if another process is already running
    if File.exist?(lock_file)
      # Check if the lock is stale (older than 10 minutes)
      if (Time.now - File.mtime(lock_file)) < 10.minutes
        puts "rappel:send_rappels skipping at #{Time.now} - another process is running"
        exit 0
      else
        # Lock is stale, we can delete it
        puts "Removing stale lock file from #{File.mtime(lock_file)}"
        File.delete(lock_file)
      end
    end
    
    begin
      # Create lock file
      FileUtils.touch(lock_file)
      
      puts "rappel:send_rappels task running at #{Time.now} with lock"
      # Let the scheduler do all the work
      RappelScheduler.process_due_rappels
      
    ensure
      # Always release the lock when done
      File.delete(lock_file) if File.exist?(lock_file)
    end
    
    puts "rappel:send_rappels task completed at #{Time.now}"
  end
end 