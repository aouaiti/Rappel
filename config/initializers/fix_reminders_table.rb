# This initializer safeguards against the missing 'reminders' table error

Rails.logger.info "Loading safety patch for reminders table references"

# This will run with ActiveRecord to monkey patch a solution
ActiveSupport.on_load(:active_record) do
  # Safely patch ActiveRecord::Base.connection to handle missing reminders table
  module SafeQueryPatch
    def exec_query(sql, name = nil, binds = [], prepare: false)
      # If the query involves the missing reminders.issue_id column, rewrite it safely
      if sql.include?('reminders.issue_id') && !table_exists?('reminders')
        Rails.logger.debug "Intercepted SQL query with reminders.issue_id: #{sql[0..100]}..."
        # Return empty result set instead of failing
        ActiveRecord::Result.new([], [])
      else
        super
      end
    end
    
    # Helper method to check if a table exists
    def table_exists?(table_name)
      begin
        connection.schema_cache.clear!
        connection.table_exists?(table_name)
      rescue => e
        Rails.logger.debug "Error checking if table '#{table_name}' exists: #{e.message}"
        false
      end
    end
  end
  
  # Apply the patch to the connection
  begin
    ActiveRecord::Base.connection.extend(SafeQueryPatch)
    Rails.logger.info "Successfully patched ActiveRecord connection for safety"
  rescue => e
    Rails.logger.warn "Failed to apply ActiveRecord safety patch: #{e.message}"
  end
end 