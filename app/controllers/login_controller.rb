class LoginController < ApplicationController
  before_filter :require_login, :except=>['index', 'login', 'render_404']
  before_filter :require_post, :only=>[:login, :logout, :update_password]
  
  def update_password
    page = 'change_password'
    flash[:notice] = if params[:password] && params[:password2]
      if params[:password].length < 6
        "Password too short, use at least 6 characters, preferably 10 or more."
      elsif params[:password] != params[:password2]
        "Passwords don't match, please try again."
      else
        user = User[session[:user_id]]
        user.password = params[:password]
        if user.save
          page = 'index'
          'Password updated.'
        else
          "Can't update account."
        end
      end
    else
      "No password provided, so can't change it."
    end
    redirect_to(:action=>page)
  end
  
  def login
    flash[:notice] = unless session[:user_id] = User.login_user_id(params[:username], params[:password])
      'Incorrect username or password.'
    else
      'You have been logged in.'
    end
    redirect_to(:action=>'index')
  end
  
  def logout
    reset_session
    flash[:notice] = 'You have been logged out.'
    redirect_to(:action=>'index')
  end
end
