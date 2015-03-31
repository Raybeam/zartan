class User < ActiveRecord::Base

  # find the user with provided auth hash
  def self.from_omniauth(auth)
    where(uid: auth["uid"]).where(email: auth["info"]["email"]).first || create_from_omniauth(auth)
  end

  # create new user from auth hash
  def self.create_from_omniauth(auth)
    user = User.new
    user.uid = auth["uid"]
    user.name = auth["info"]["name"]
    user.email = auth["info"]["email"]
    user.save
    return user
  end

end
