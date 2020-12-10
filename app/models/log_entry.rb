class LogEntry
  attr_reader :id, :name

  def initialize(id:, name:, require_user: false, require_application: false)
    @id = id
    @name = name
    @require_user = require_user
    @require_application = require_application
  end

  def require_user?
    @require_user
  end

  def require_application?
    @require_application
  end
end
