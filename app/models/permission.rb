class Permission
  def initialize(user)
    if user.nil?
      allow 'home', [:index]
      allow 'sessions', [:create]
      allow 'api/version1_controller', [:get_proxy, :report_result]
    else
      allow_all
    end
  end
  
  def allow?(controller, action, user = nil)
    allowed = @allow_all || @allowed_actions[[controller.to_s, action.to_s]]
    allowed && (allowed == true || user && allowed.call(user))
  end
  
  def allow_all
    @allow_all = true
  end
  
  def allow(controllers, actions, &block)
    @allowed_actions ||= {}
    Array(controllers).each do |controller|
      Array(actions).each do |action|
        @allowed_actions[[controller.to_s, action.to_s]] = block || true
      end
    end
  end
end